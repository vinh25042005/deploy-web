#!/usr/bin/env bash
# =============================================================================
# vault-seed.sh — (Re)seed Vault VM: init + KV + auth + toàn bộ secret + policy/role
# Chạy TRÊN VM (đã có IAM role đọc SSM + vault CLI + CA local):
#   ssh ubuntu@<VAULT_EIP> 'bash -s' < terraform/vault-standalone/vault-seed.sh ap-southeast-1
# IDEMPOTENT — chạy lại thoải mái.
# =============================================================================
set -euo pipefail

REGION="${1:-ap-southeast-1}"
SSM="/techshop"
export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="/etc/vault/tls/ca.crt"

echo ">>> [1/7] Đảm bảo Vault reachable..."
for i in $(seq 1 15); do
  if vault status -format=json >/dev/null 2>&1; then break; fi
  sleep 2
done

# ── Init nếu chưa (KMS auto-unseal — không cần unseal thủ công) ──
INIT=$(vault status -format=json 2>/dev/null | jq -r '.initialized // false' 2>/dev/null || echo false)
if [ "$INIT" != "true" ]; then
  echo ">>> [2/7] Init Vault (KMS auto-unseal)..."
  INIT_JSON=$(vault operator init -format=json)
  ROOT_TOKEN=$(echo "$INIT_JSON" | jq -r .root_token)
  aws ssm put-parameter --name "$SSM/vault-root-token" --value "$ROOT_TOKEN" \
    --type SecureString --overwrite --region "$REGION"
else
  echo ">>> [2/7] Vault đã initialized — lấy root token từ SSM..."
  ROOT_TOKEN=$(aws ssm get-parameter --name "$SSM/vault-root-token" --with-decryption \
    --region "$REGION" --query Parameter.Value --output text)
fi
export VAULT_TOKEN="$ROOT_TOKEN"

echo ">>> [3/7] Enable kv-v2 + kubernetes auth..."
vault secrets enable -path=secret kv-v2 2>/dev/null || true
vault auth enable kubernetes 2>/dev/null || true

echo ">>> [4/7] Seed app secrets (từ SSM)..."
for pair in "postgres:postgres-password" "grafana:grafana-password" "jwt:jwt-secret" "database:database-url"; do
  path="${pair%%:*}"; param="${pair##*:}"
  val=$(aws ssm get-parameter --name "$SSM/$param" --with-decryption --region "$REGION" \
    --query Parameter.Value --output text 2>/dev/null || echo "")
  if [ -n "$val" ]; then
    case "$path" in
      postgres)  vault kv put secret/postgres password="$val" ;;
      grafana)   vault kv put secret/grafana admin_password="$val" admin_username="admin" ;;
      jwt)       vault kv put secret/jwt secret="$val" ;;
      database)  vault kv put secret/database url="$val" ;;
    esac
  fi
done

# Cosign public key — đọc từ SSM nếu có, nếu không thì file local (seed tay)
COSIGN_PUB=$(aws ssm get-parameter --name "$SSM/cosign-public-key" --with-decryption \
  --region "$REGION" --query Parameter.Value --output text 2>/dev/null || cat /root/cosign.pub 2>/dev/null || echo "")
if [ -n "$COSIGN_PUB" ]; then
  vault kv put secret/cosign public_key="$COSIGN_PUB"
fi

echo ">>> [5/7] Seed CI credentials (từ SSM)..."
GH_TOKEN=$(aws ssm get-parameter --name "$SSM/github-token" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$GH_TOKEN" ]; then
  GH_USER=$(aws ssm get-parameter --name "$SSM/github-username" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "x-access-token")
  vault kv put secret/ci/github username="$GH_USER" token="$GH_TOKEN"
fi
DOCKER_PAT=$(aws ssm get-parameter --name "$SSM/docker-pat" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
if [ -n "$DOCKER_PAT" ]; then
  DOCKER_USER=$(aws ssm get-parameter --name "$SSM/docker-username" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "vinh2504")
  vault kv put secret/ci/dockerhub username="$DOCKER_USER" token="$DOCKER_PAT"
fi
SONAR=$(aws ssm get-parameter --name "$SSM/sonar-token" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
[ -n "$SONAR" ] && vault kv put secret/ci/sonar token="$SONAR"
COSIGN_KEY=$(aws ssm get-parameter --name "$SSM/cosign-private-key" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
[ -n "$COSIGN_KEY" ] && vault kv put secret/ci/cosign private_key="$COSIGN_KEY"

echo ">>> [6/7] Policy techshop (read-only, gồm cả ci/*)..."
cat > /tmp/techshop-policy.hcl <<EOF
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
vault policy write techshop /tmp/techshop-policy.hcl

echo ">>> [7/7] Roles k8s auth..."
vault write auth/kubernetes/role/techshop \
  bound_service_account_names="*" \
  bound_service_account_namespaces="techshop-dev,techshop-stg" \
  policies=techshop \
  ttl=24h
vault write auth/kubernetes/role/techshop-jenkins \
  bound_service_account_names="jenkins-ci" \
  bound_service_account_namespaces="techshop-dev" \
  policies=techshop \
  ttl=1h

echo ""
echo "======================================================"
echo "✅ Vault VM seeded. VAULT_ADDR=https://<EIP>:8200"
echo "   (còn bước cấu hình k8s auth — xem runbook)"
echo "======================================================"
