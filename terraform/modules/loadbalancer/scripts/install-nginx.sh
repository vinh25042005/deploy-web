#!/bin/bash
set -e
apt-get update
apt-get install -y nginx

# Tạo upstream với IP thật từ Terraform
cat <<'NGINXEOF' > /etc/nginx/sites-available/default
upstream k8s_ingress {
NGINXEOF
%{ for ip in node_ips ~}
echo "    server ${ip}:${backend_port} max_fails=3 fail_timeout=30s;" >> /etc/nginx/sites-available/default
%{ endfor ~}
cat <<'NGINXEOF' >> /etc/nginx/sites-available/default
}
server {
    listen 80;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    ssl_certificate     /etc/nginx/ssl/lb.crt;
    ssl_certificate_key /etc/nginx/ssl/lb.key;
    location / {
        proxy_pass http://k8s_ingress;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINXEOF

mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/lb.key -out /etc/nginx/ssl/lb.crt -subj "/CN=lb"

systemctl restart nginx && systemctl enable nginx
