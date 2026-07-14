#!/bin/bash
# Rancher Server init script
# Cài Docker + Rancher trên EC2 riêng, nằm NGOÀI cụm K8s
set -e

RANCHER_VERSION="${rancher_version}"
BOOTSTRAP_PASSWORD="${bootstrap_password}"
LOG_FILE="/var/log/rancher-init.log"

exec > >(tee -a $LOG_FILE) 2>&1
echo "[$(date)] Starting Rancher init..."

# ── 1. Cài Docker ──
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  usermod -aG docker ubuntu
fi

# ── 2. Chạy Rancher ──
echo "Starting Rancher v$RANCHER_VERSION..."
docker run -d --restart=unless-stopped \
  --name rancher \
  --privileged \
  -p 80:80 \
  -p 443:443 \
  -e CATTLE_BOOTSTRAP_PASSWORD="$BOOTSTRAP_PASSWORD" \
  "rancher/rancher:v$RANCHER_VERSION"

# ── 3. Đợi Rancher ready ──
echo "Waiting for Rancher to be ready..."
for i in $(seq 1 60); do
  if curl -sk https://localhost/ping 2>/dev/null | grep -q "pong"; then
    echo "[$(date)] Rancher is ready!"
    break
  fi
  sleep 10
done

echo "[$(date)] Rancher init complete!"
echo "  URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "  Login: admin / $BOOTSTRAP_PASSWORD"
