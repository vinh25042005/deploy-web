#!/usr/bin/env bash
# =============================================================================
# configure-ci-vault.sh — (Re)configure Vault cho Jenkins CI
#
# Mục đích: cho phép luồng CI đọc secret TRỰC TIẾP từ Vault (không qua ESO → k8s).
#   - Lưu CI credentials (github / dockerhub / sonar / cosign-private) vào Vault
#     (giá trị đọc từ AWS SSM — không hardcode).
#   - Cập nhật policy `techshop` (thêm path secret/data/ci/*).
#   - Tạo role auth/kubernetes/role/techshop-jenkins (SA jenkins-ci, ttl ngắn).
#   - Đảm bảo ServiceAccount `jenkins-ci` tồn tại (fallback — ArgoCD sẽ quản lý
#     qua Helm chart helm/techshop/templates/rbac.yaml).
#
# IDEMPOTENT — chạy lại thoải mái. Chạy trên host có aws cli + kubectl
# (có kubeconfig trỏ tới cluster).
#
# Usage: configure-ci-vault.sh <aws-region>
# =============================================================================
set -euo pipefail

REGION="${1:-ap-southeast-1}"
VAULT_NS="vault"
VAULT_POD="vault-0"
SSM_PREFIX="/techshop"

echo ">>> Lấy root token từ SSM ($SSM_PREFIX/vault-root-token)..."
ROOT_TOKEN=$(aws ssm get-parameter --name "$SSM_PREFIX/vault-root-token" \
  --with-decryption --region "$REGION" --query Parameter.Value --output text)

echo ">>> [1/5] Kiểm tra Vault reachable..."
if ! kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault status >/dev/null 2>&1; then
  echo "ERROR: Vault chưa sẵn sàng — kiểm tra: kubectl get pod -n vault vault-0"
  exit 1
fi

echo ">>> [2/5] Lưu CI credentials vào Vault (đọc từ SSM, không hardcode)..."
# ── GitHub ──
GH_TOKEN=$(aws ssm get-parameter --name "$SSM_PREFIX/github-token" \
  --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$GH_TOKEN" ]; then
  GH_USER=$(aws ssm get-parameter --name "$SSM_PREFIX/github-username" \
    --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "x-access-token")
  kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault kv put secret/ci/github username="$GH_USER" token="$GH_TOKEN"
else
  echo "  ⚠️  SSM $SSM_PREFIX/github-token trống — bỏ qua secret/ci/github"
fi

# ── Docker Hub ──
DOCKER_PAT=$(aws ssm get-parameter --name "$SSM_PREFIX/docker-pat" \
  --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$DOCKER_PAT" ]; then
  DOCKER_USER=$(aws ssm get-parameter --name "$SSM_PREFIX/docker-username" \
    --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "vinh2504")
  kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault kv put secret/ci/dockerhub username="$DOCKER_USER" token="$DOCKER_PAT"
else
  echo "  ⚠️  SSM $SSM_PREFIX/docker-pat trống — bỏ qua secret/ci/dockerhub"
fi

# ── Sonar ──
SONAR_TOKEN=$(aws ssm get-parameter --name "$SSM_PREFIX/sonar-token" \
  --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$SONAR_TOKEN" ]; then
  kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault kv put secret/ci/sonar token="$SONAR_TOKEN"
else
  echo "  ⚠️  SSM $SSM_PREFIX/sonar-token trống — bỏ qua secret/ci/sonar"
fi

# ── Cosign private key (dùng để sign image ở CI) ──
COSIGN_KEY=$(aws ssm get-parameter --name "$SSM_PREFIX/cosign-private-key" \
  --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$COSIGN_KEY" ]; then
  kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault kv put secret/ci/cosign private_key="$COSIGN_KEY"
else
  echo "  ⚠️  SSM $SSM_PREFIX/cosign-private-key trống — bỏ qua secret/ci/cosign"
fi

echo ">>> [3/5] Cập nhật policy techshop (thêm path secret/data/ci/*)..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  sh -c 'cat > /tmp/techshop-policy.hcl << EOF
path "secret/data/postgres"    { capabilities = ["read"] }
path "secret/data/jwt"         { capabilities = ["read"] }
path "secret/data/grafana"     { capabilities = ["read"] }
path "secret/data/database"    { capabilities = ["read"] }
path "secret/data/cosign"      { capabilities = ["read"] }
path "secret/data/ci/github"    { capabilities = ["read"] }
path "secret/data/ci/dockerhub" { capabilities = ["read"] }
path "secret/data/ci/sonar"     { capabilities = ["read"] }
path "secret/data/ci/cosign"    { capabilities = ["read"] }
EOF
vault policy write techshop /tmp/techshop-policy.hcl'

echo ">>> [4/5] Tạo role auth/kubernetes/role/techshop-jenkins (SA jenkins-ci, least-privilege, ttl 1h)..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault write auth/kubernetes/role/techshop-jenkins \
  bound_service_account_names="jenkins-ci" \
  bound_service_account_namespaces="techshop-dev" \
  policies=techshop \
  ttl=1h

echo ">>> [5/5] Đảm bảo ServiceAccount jenkins-ci tồn tại (fallback nếu ArgoCD chưa sync)..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-ci
  namespace: techshop-dev
EOF

echo ""
echo "✅ Đã cấu hình Vault cho Jenkins CI."
echo "   Kiểm tra: kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/techshop-jenkins"
echo "   Nếu thiếu secret nào, seed SSM rồi chạy lại script này."
