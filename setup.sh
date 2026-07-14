#!/bin/bash
# ============================================================
# Setup K8s Cluster + App (chạy sau terraform apply)
# ============================================================
# Cách dùng:
#   terraform apply -auto-approve
#   bash setup.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Bước 0: Kiểm tra SSH agent ───
info "Bước 0: Kiểm tra SSH agent..."
if ! ssh-add -l &>/dev/null; then
  warn "SSH agent chưa chạy. Khởi động..."
  eval $(ssh-agent -s) > /dev/null
  ssh-add ~/.ssh/techshop-key.pem 2>/dev/null || warn "Không tìm thấy ~/.ssh/techshop-key.pem"
fi

# ─── Bước 1: Ansible ───
info ""
info "╔══════════════════════════════════════╗"
info "║  Bước 1: Cài K8s cluster bằng Ansible  ║"
info "╚══════════════════════════════════════╝"
info ""

cd "$SCRIPT_DIR/ansible"

# Copy key lên master (để master SSH vào worker nodes)
MASTER_IP=$(head -1 inventory.ini | grep -oP '(?<=ansible_host=)[^ ]+' || true)
if [ -n "$MASTER_IP" ]; then
  info "Copy key lên master ($MASTER_IP)..."
  ssh -i ~/.ssh/techshop-key.pem -o StrictHostKeyChecking=no "ubuntu@$MASTER_IP" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null || true
  scp -i ~/.ssh/techshop-key.pem -o StrictHostKeyChecking=no \
    ~/.ssh/techshop-key.pem "ubuntu@$MASTER_IP:~/.ssh/" 2>/dev/null || true
fi

info "Chạy Ansible playbook..."
ansible-playbook -i inventory.ini playbooks/k8s-cluster.yml

info "✅ Ansible hoàn tất!"

# ─── Bước 2: Lấy kubeconfig ───
info ""
info "╔════════════════════════════════════╗"
info "║  Bước 2: Lấy kubeconfig từ SSM      ║"
info "╚════════════════════════════════════╝"
info ""

mkdir -p ~/.kube
echo "Đợi kubeconfig từ SSM..."
for i in $(seq 1 60); do
  VALUE=$(aws ssm get-parameter --region ap-southeast-1 \
    --name /k8s/kubeconfig --query Parameter.Value --output text 2>/dev/null)
  if [ -n "$VALUE" ] && [ "$VALUE" != "None" ]; then
    echo "$VALUE" | base64 -d | gzip -d > ~/.kube/techshop-config 2>/dev/null
    if [ -f ~/.kube/techshop-config ] && grep -q 'server:' ~/.kube/techshop-config; then
      info "✅ Kubeconfig OK! Server: $(grep 'server:' ~/.kube/techshop-config | head -1)"
      break
    fi
  fi
  echo "  Đợi... ($i/12)"
  sleep 10
done

export KUBECONFIG=~/.kube/techshop-config
kubectl get nodes

# ─── Bước 3: Helm deploy ───
info ""
info "╔════════════════════════════════════╗"
info "║  Bước 3: Deploy app + monitoring    ║"
info "╚════════════════════════════════════╝"
info ""

cd "$SCRIPT_DIR/helm/techshop"

info "Cập nhật Helm dependencies..."
helm dependency update 2>/dev/null || true

info "Deploy Helm chart..."
helm upgrade --install techshop-dev . \
  --namespace techshop \
  --create-namespace \
  --set images.backend=nginx:alpine \
  --set images.frontend=nginx:alpine \
  --set images.postgres=postgres:16-alpine \
  --set hpa.enabled=false \
  --set monitoring.enabled=true \
  --set monitoring.loki.enabled=false \
  --set monitoring.promtail.enabled=false \
  --wait --timeout 10m

info "✅ Helm deploy hoàn tất!"

# ─── Bước 4: Verify infrastructure dependencies ───
info ""
info "╔════════════════════════════════════╗"
info "║  Bước 4: Verify Storage + Ingress   ║"
info "╚════════════════════════════════════╝"
info ""

# EBS CSI driver & ingress-nginx đã được cài tự động qua Helm dependency
info "Đợi EBS CSI driver ready..."
kubectl wait -n kube-system --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver --timeout=180s 2>/dev/null || warn "EBS CSI driver chưa ready, PVC có thể Pending"
info "Đợi ingress-nginx ready..."
kubectl wait -n techshop --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx --timeout=180s 2>/dev/null || warn "ingress-nginx chưa ready"

# ─── Done ───
info ""
info "╔════════════════════════════════════╗"
info "║  ✅ HOÀN TẤT!                       ║"
info "╚════════════════════════════════════╝"
info ""
kubectl get nodes
kubectl get pods -n techshop
info ""
info "Grafana: kubectl port-forward -n techshop svc/techshop-dev-grafana 9999:80"
info "         → http://localhost:9999 (admin/admin123)"
info ""
info "Backend: kubectl port-forward -n techshop svc/backend 3001:3001"
info "Frontend: Access qua ingress node IP + header Host: techshop.local"
