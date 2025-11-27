#!/bin/bash
# 文件名: interactive_setup_v23.sh
# 目标: V23 交互式版本：继承 V22 的所有成功修复，并将四个关键参数改为交互式输入。

# --- 0. 交互式参数输入 ---
echo "--- 欢迎使用 ZeroSSL IP SSL 证书一键部署脚本 (V23) ---"
echo "请准备好您的 ZeroSSL API Key、公网 IP 和反代目标地址。"

read -p "1. 请输入您的 ZeroSSL API Key: " API_KEY
read -p "2. 请输入您的服务器公网 IP 地址 (用于证书): " PUBLIC_IP
read -p "3. 请输入您的邮箱地址 (用于证书): " CERT_EMAIL
read -p "4. 请输入反向代理的目标地址 (例如: https://123.abc123.com): " PROXY_TARGET

# 简单验证输入是否为空
if [ -z "$API_KEY" ] || [ -z "$PUBLIC_IP" ] || [ -z "$CERT_EMAIL" ] || [ -z "$PROXY_TARGET" ]; then
    echo "错误：所有参数都必须填写。脚本终止。"
    exit 1
fi

echo ""
echo "--- 配置确认 ---"
echo "API Key: $API_KEY"
echo "公网 IP: $PUBLIC_IP"
echo "邮箱: $CERT_EMAIL"
echo "目标: $PROXY_TARGET"
echo "-------------------"
echo "按任意键继续，或按 Ctrl+C 取消。"
read -n 1 -s

# --- 路径配置 (无需修改) ---
CERT_SCRIPT_PATH="/root/ip_api_renew.sh"
WEBROOT_DIR="/var/www/acme_challenges"
CERT_DEPLOY_DIR="/etc/nginx/ssl/ip_cert"
KEY_PATH="$CERT_DEPLOY_DIR/ip_cert.key"
FULLCHAIN_PATH="$CERT_DEPLOY_DIR/ip_cert_full.crt"
TEMP_NGINX_CONF="/etc/nginx/conf.d/temp-zerossl.conf"
FINAL_NGINX_CONF="/etc/nginx/conf.d/default.conf"
NGINX_MAIN_CONF="/etc/nginx/nginx.conf"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# --- 1. 准备阶段：安装依赖并清理配置 ---
echo "--- 1. 准备阶段：安装依赖并清理配置 ---"
sudo apt update
sudo apt install -y curl jq openssl nginx dos2unix
if [ $? -ne 0 ]; then
    echo "致命错误: 依赖安装失败。"
    exit 1
fi

if ! command -v mktemp &> /dev/null; then
    echo "致命错误: mktemp 命令不存在，无法继续。"
    exit 1
fi

sudo mkdir -p "$CERT_DEPLOY_DIR"
sudo mkdir -p "$WEBROOT_DIR/.well-known/pki-validation"

# 强制停止 Nginx 服务并禁用其自动启动 
sudo systemctl stop nginx
sudo systemctl disable nginx 2>/dev/null 
echo "Nginx 服务已停止并禁用自动启动。"

# 清理所有可能冲突的配置和默认页面
sudo rm -f /etc/nginx/conf.d/*.conf
sudo rm -f /etc/nginx/sites-enabled/*
sudo rm -f /etc/nginx/sites-available/*
sudo rm -f /var/www/html/index.nginx-debian.html
sudo rm -f /var/www/html/index.html
echo "已清除所有默认和遗留的 Nginx 配置/默认文件。"

# --- 2. 证书申请阶段：部署临时 80 端口配置 ---
echo "--- 2. 证书申请阶段：部署临时 80 端口配置 ($TEMP_NGINX_CONF) ---"
sudo tee "$TEMP_NGINX_CONF" > /dev/null <<EOF
# 临时配置：只用于 ZeroSSL HTTP 验证 (模仿成功案例)
server {
    listen 80; 
    listen [::]:80; 
    # server_name $PUBLIC_IP; 
    
    # ZeroSSL 验证路径
    location /.well-known/pki-validation/ {
        alias $WEBROOT_DIR/.well-known/pki-validation/;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    # 任何其他请求都返回 404
    location / {
        return 404;
    }
}
EOF

# 启动 Nginx 
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "致命错误：临时 Nginx 配置测试失败。请检查语法。"
    exit 1
fi
sudo systemctl start nginx
echo "临时 Nginx (80 端口) 已启动，准备进行完整的证书申请..."

# --- 3. 生成并运行核心 ZeroSSL 续期脚本 (恢复完整流程) ---
echo "--- 3. 正在生成核心 ZeroSSL 续期脚本 ($CERT_SCRIPT_PATH) ---"

# 完整的核心脚本模板 
CORE_SCRIPT_TEMPLATE=$(cat <<'EOF_CORE_TEMPLATE'
#!/bin/bash
# 文件名: /root/ip_api_renew.sh
# 目标: V23 核心脚本：ZeroSSL IP 证书自动续期 (完整流程)

# --- 配置参数 (由父脚本替换) ---
API_KEY="%API_KEY_VAR%"
PUBLIC_IP="%PUBLIC_IP_VAR%"
CERT_EMAIL="%CERT_EMAIL_VAR%"              
CERT_DEPLOY_DIR="%CERT_DEPLOY_DIR_VAR%"
KEY_PATH="%CERT_DEPLOY_DIR_VAR%/ip_cert.key"
CSR_PATH="%CERT_DEPLOY_DIR_VAR%/ip_cert.csr"
FULLCHAIN_PATH="%FULLCHAIN_PATH_VAR%"
WEBROOT_VALIDATION_PATH="%WEBROOT_DIR_VAR%/.well-known/pki-validation" 

# --- 核心操作开始 ---
if ! command -v jq &> /dev/null || ! command -v openssl &> /dev/null || ! command -v dos2unix &> /dev/null; then
    exit 1
fi

echo "--- 1. 生成或复用 CSR 和私钥 ---"
mkdir -p "$CERT_DEPLOY_DIR"
if [ ! -f "$KEY_PATH" ]; then
    echo "私钥不存在，重新生成..."
    openssl genrsa -out "$KEY_PATH" 2048
else
    echo "私钥已存在，跳过生成。"
fi
openssl req -new -key "$KEY_PATH" -out "$CSR_PATH" -subj "/CN=$PUBLIC_IP/emailAddress=$CERT_EMAIL"
CSR_CONTENT=$(grep -v 'REQUEST' "$CSR_PATH" | tr -d '\n' | tr -d ' ')

echo "--- 2. 创建新证书订单 ---"
ORDER_URL="https://api.zerossl.com/certificates"
JSON_DATA=$(mktemp)
ORDER_URL_WITH_KEY="$ORDER_URL?access_key=$API_KEY" 

cat > "$JSON_DATA" <<EOT
{
  "validation_method": "HTTP_ROOT",  
  "certificate_csr": "$CSR_CONTENT",         
  "certificate_validity_days": 90,
  "certificate_domains": "$PUBLIC_IP"
}
EOT

RESPONSE=$(curl -s -X POST "$ORDER_URL_WITH_KEY" -H "Content-Type: application/json" --data "@$JSON_DATA")
rm -f "$JSON_DATA"
CERT_ID=$(echo "$RESPONSE" | jq -r '.id')

if [ -z "$CERT_ID" ] || [ "$CERT_ID" == "null" ]; then
    echo "错误：创建订单失败。API 响应: $RESPONSE"
    exit 1
fi
echo "成功创建订单，证书ID: $CERT_ID"

echo "--- 3. 获取验证信息并部署文件 ---"
VALIDATION_OBJECT=$(echo "$RESPONSE" | jq -r '.validation.other_methods | to_entries[0].value')

FILE_NAME=$(echo "$VALIDATION_OBJECT" | jq -r '.file_validation_url_http' | sed 's/.*pki-validation\///' | sed 's/\.txt//').txt
FILE_CONTENT=$(echo "$VALIDATION_OBJECT" | jq -r '.file_validation_content | join("\n")')

if [ "$FILE_NAME" == "null" ] || [ -z "$FILE_CONTENT" ]; then
    echo "错误：无法提取 HTTP 验证信息。"
    exit 1
fi

mkdir -p "$WEBROOT_VALIDATION_PATH" 
echo -n "$FILE_CONTENT" > "$WEBROOT_VALIDATION_PATH/$FILE_NAME"
echo "验证文件已部署: $FILE_NAME"

echo "--- 4. 提交验证并等待 CA 确认 (关键步骤) ---"
VALIDATE_URL="https://api.zerossl.com/certificates/$CERT_ID/challenges"
VALIDATE_URL_WITH_KEY="$VALIDATE_URL?access_key=$API_KEY"

curl -s -X POST "$VALIDATE_URL_WITH_KEY" -H "Content-Type: application/json" --data '{"validation_method": "HTTP_CSR_HASH"}' > /dev/null

MAX_ATTEMPTS=15 
ATTEMPT_COUNT=0
CERT_STATUS=""
STATUS_URL="https://api.zerossl.com/certificates/$CERT_ID"
STATUS_URL_WITH_KEY="$STATUS_URL?access_key=$API_KEY"

while [ "$CERT_STATUS" != "issued" ] && [ $ATTEMPT_COUNT -lt $MAX_ATTEMPTS ]; do
    sleep 10
    ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))
    STATUS_RESPONSE=$(curl -s "$STATUS_URL_WITH_KEY")
    CERT_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
    
    if [ "$CERT_STATUS" == "issued" ]; then
        break
    elif [ "$CERT_STATUS" == "validation_failed" ]; then
        echo "验证失败。"
        exit 1
    fi
done

if [ "$CERT_STATUS" != "issued" ]; then
    echo "超时未颁发。请检查云防火墙 80 端口是否开放。"
    exit 1
fi

echo "--- 5. 下载证书文件并强制清理格式 ---"
DOWNLOAD_URL="https://api.zerossl.com/certificates/$CERT_ID/download/return"
DOWNLOAD_URL_WITH_KEY="$DOWNLOAD_URL?access_key=$API_KEY" 

DOWNLOAD_RESPONSE=$(curl -s "$DOWNLOAD_URL_WITH_KEY")
CERTIFICATE=$(echo "$DOWNLOAD_RESPONSE" | jq -r '."certificate.crt" // empty')
CA_BUNDLE=$(echo "$DOWNLOAD_RESPONSE" | jq -r '."ca_bundle.crt" // empty')

if [ -z "$CERTIFICATE" ] || [ -z "$CA_BUNDLE" ]; then
    echo "下载失败，证书可能仍在颁发中或已过期。"
    exit 1
fi

# 写入临时文件
TEMP_CERT_FILE=$(mktemp)
echo "$CERTIFICATE" > "$TEMP_CERT_FILE"
echo "$CA_BUNDLE" >> "$TEMP_CERT_FILE"

# *** 强制清理 PEM 格式 ***
sudo dos2unix "$TEMP_CERT_FILE" 2>/dev/null
sudo cat "$TEMP_CERT_FILE" | grep -v '^\s*$' | tr -d '\r' > "$FULLCHAIN_PATH" 
sudo sed -i '/-END CERTIFICATE-/{N;s/-END CERTIFICATE-\n\?-BEGIN/-END CERTIFICATE-\n-BEGIN/}' "$FULLCHAIN_PATH"

rm -f "$TEMP_CERT_FILE"
echo "证书下载并强制清理格式成功。"

# 核心脚本结束
EOF_CORE_TEMPLATE
)

# 使用 sed 替换模板中的占位符
CORE_SCRIPT_FINAL=$(echo "$CORE_SCRIPT_TEMPLATE" | \
    sed "s|%API_KEY_VAR%|$API_KEY|g" | \
    sed "s|%PUBLIC_IP_VAR%|$PUBLIC_IP|g" | \
    sed "s|%CERT_EMAIL_VAR%|$CERT_EMAIL|g" | \
    sed "s|%CERT_DEPLOY_DIR_VAR%|$CERT_DEPLOY_DIR|g" | \
    sed "s|%FULLCHAIN_PATH_VAR%|$FULLCHAIN_PATH|g" | \
    sed "s|%WEBROOT_DIR_VAR%|$WEBROOT_DIR|g"
)

# 写入最终的脚本文件
echo "$CORE_SCRIPT_FINAL" | sudo tee "$CERT_SCRIPT_PATH" > /dev/null
sudo chmod +x "$CERT_SCRIPT_PATH"
echo "核心续期脚本生成完毕。"

# 运行核心脚本，获取证书
echo "--- 3.1. 首次运行核心续期脚本，获取证书 ---"
sudo bash "$CERT_SCRIPT_PATH"
if [ $? -ne 0 ]; then
    echo "--- 致命证书申请失败 ---"
    sudo systemctl stop nginx
    echo "Nginx 已停止。"
    exit 1
fi
echo "证书已成功生成并部署到 $CERT_DEPLOY_DIR。"

# --- 4. 部署阶段：切换到最终反代配置 (conf.d) ---
echo "--- 4. 部署阶段：切换到最终反代配置 ($FINAL_NGINX_CONF) ---"

# 停止 Nginx 并清理临时配置
sudo systemctl stop nginx
sudo rm -f "$TEMP_NGINX_CONF"

# 写入最终的 Nginx 配置 (模仿成功案例)
sudo tee "$FINAL_NGINX_CONF" > /dev/null <<EOF
# Nginx 配置由 V23 终极脚本生成 (最终反代配置 - 模仿成功案例)

# 证书验证和 HTTP 重定向 (80 端口 - 模仿成功案例)
server {
    listen 80;
    listen [::]:80;
    # server_name $PUBLIC_IP; 
    
    # ZeroSSL 验证路径 (保留，用于后续续期)
    location /.well-known/pki-validation/ {
        alias $WEBROOT_DIR/.well-known/pki-validation/;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    # 其他 HTTP 请求，重定向到默认 HTTPS 端口 (8443)
    location / {
        return 301 https://\$host:8443\$request_uri;
    }
}

# HTTPS 反代服务 (8443 和 2621 端口)
server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    listen 2621 ssl;
    listen [::]:2621 ssl;
    server_name $PUBLIC_IP;

    ssl_certificate     $FULLCHAIN_PATH;
    ssl_certificate_key $KEY_PATH;

    ssl_session_timeout 1d;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # 反向代理配置
    location / {
        proxy_pass $PROXY_TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOF

# 启动 Nginx
echo "--- Nginx 最终配置测试 (包含 SSL 证书) ---"
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "致命错误：最终 Nginx 配置测试失败。请手动检查 $FINAL_NGINX_CONF 文件。"
    exit 1
fi
sudo systemctl start nginx
echo "🎉 Nginx 已成功启动，HTTPS 反代已生效！"

# --- 5. 设置自动续期定时任务 ---
echo "--- 5. 设置 Cron Job 自动续期 ---"
CRON_JOB="0 3 1 * * $CERT_SCRIPT_PATH > /var/log/zerossl_renew.log 2>&1"

if ! sudo crontab -l | grep -q "$CERT_SCRIPT_PATH"; then
    (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
    echo "Cron Job 已成功添加，证书将每月自动续期。"
fi

echo "--- 部署完成 ---"