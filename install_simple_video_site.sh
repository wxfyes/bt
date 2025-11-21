#!/bin/bash

# 用户输入域名和站点信息
echo "请输入你的视频站点的域名（例如：yourdomain.com）:"
read DOMAIN_NAME

# 确认域名输入
if [ -z "$DOMAIN_NAME" ]; then
    echo "域名不能为空！退出脚本..."
    exit 1
fi

echo "你输入的域名是: $DOMAIN_NAME"
echo "请确保你的域名已正确指向此服务器的 IP 地址。"

# 等待用户确认
read -p "按 Enter 键继续执行安装或 Ctrl+C 取消操作..."

# 更新系统并安装必要的软件包
echo "更新系统并安装必要的软件包..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx wget unzip curl certbot python3-certbot-nginx

# 设置防火墙规则，允许 80, 443 和 8443 端口
echo "设置防火墙规则..."
sudo ufw allow 80,443,8443/tcp
sudo ufw enable

# 安装 SSL 证书
echo "安装 SSL 证书..."
# 使用 certbot 为域名申请 SSL 证书
sudo certbot --nginx -d $DOMAIN_NAME

# 创建网站根目录
echo "创建网站根目录..."
sudo mkdir -p /var/www/simple_video_site
sudo chown -R $USER:$USER /var/www/simple_video_site

# 创建简单的视频管理页面
echo "创建视频管理页面..."
cat <<EOL | sudo tee /var/www/simple_video_site/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>升国旗站点</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
        }
        header {
            background-color: #333;
            color: white;
            text-align: center;
            padding: 10px 0;
        }
        .video-container {
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 20px;
            padding: 20px;
        }
        .video-item {
            width: 800px;
            text-align: center;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
        }
        .video-item video {
            width: 100%;
            border-bottom: 1px solid #ddd;
        }
        .video-item h3 {
            padding: 10px;
            margin: 0;
            font-size: 18px;
            color: #333;
        }
        .upload-container {
            text-align: center;
            margin: 20px 0;
        }
        input[type="file"] {
            margin-bottom: 10px;
        }
    </style>
</head>
<body>

<header>
    <h1>欢迎来到升国旗站点</h1>
</header>


<div class="video-container">
    <!-- 视频项目 -->
    <!-- 这里可以动态生成视频列表 -->
    <div class="video-item">
        <video controls>
            <source src="/uploads/04fcaa50-b6ea-4e4f-b548-f0758cab8c64.mp4" type="video/mp4">
            您的浏览器不支持 video 标签。
        </video>
        <h3>中华人民共和国国歌</h3>
    </div>
</div>

</body>
</html>
EOL

# 配置 NGINX
echo "配置 NGINX..."
cat <<EOL | sudo tee /etc/nginx/sites-available/simple_video_site
server {
    listen 8443 ssl;
    server_name $DOMAIN_NAME;  # 替换为用户输入的域名

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;

    root /var/www/simple_video_site;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /uploads/ {
        root /var/www/simple_video_site;
        autoindex on;
        allow all;
    }
}
EOL

# 创建符号链接启用站点
echo "启用站点配置..."
sudo ln -s /etc/nginx/sites-available/simple_video_site /etc/nginx/sites-enabled/

# 检查 NGINX 配置
echo "检查 NGINX 配置..."
sudo nginx -t

# 重启 NGINX
echo "重启 NGINX..."
sudo systemctl restart nginx

# 完成安装
echo "视频站点安装完成！"
