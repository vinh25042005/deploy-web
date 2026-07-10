#!/bin/bash
set -e
apt-get update && apt-get install -y docker.io
systemctl enable docker && systemctl start docker
docker run -d --name rancher-server --restart unless-stopped \
  -p 80:80 -p 443:443 \
  --privileged \
  rancher/rancher:${rancher_version}
echo "Rancher ready: https://$(curl -s http://checkip.amazonaws.com)"
