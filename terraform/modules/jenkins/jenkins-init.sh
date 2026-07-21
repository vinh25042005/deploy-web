#!/bin/bash
set -euxo pipefail

# ─── Cài Docker ───
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo chmod 666 /var/run/docker.sock

# ─── Cài Node.js (cho npm ci, lint, test) ───
sudo apt-get update -qq
sudo apt-get install -y -qq nodejs npm 2>&1 | tail -3

# ─── Chạy Jenkins container ───
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p ${jenkins_port}:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts-jdk21

# ─── Đợi Jenkins khởi động ───
sleep 60

# ─── Cài plugins mặc định + cần thiết ───
sudo docker exec jenkins jenkins-plugin-cli --plugins \
  docker-workflow \
  kubernetes-cli \
  blueocean \
  git \
  pipeline-stage-view \
  pipeline-stage-step \
  pipeline-input-step \
  pipeline-build-step \
  credentials-binding \
  ssh-slaves \
  matrix-auth \
  email-ext \
  workflow-aggregator

# ─── In mật khẩu admin ───
echo "========================================"
echo "Jenkins initial admin password:"
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
echo "========================================"
