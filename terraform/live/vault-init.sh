#!/usr/bin/env bash
# =============================================================================
# vault-init.sh — Initialize + configure HashiCorp Vault on K8s
# Usage: vault-init.sh <aws-region>
# =============================================================================
set -euo pipefail

REGION="${1:-ap-southeast-1}"
VAULT_NS="vault"
VAULT_POD="vault-0"
SSM_PREFIX="/techshop"

echo ">>> [1/9] Waiting for Vault pod to be Running (not Ready — Vault needs init first)..."
for i in $(seq 1 30); do
  PHASE=$(kubectl get pod -n "$VAULT_NS" "$VAULT_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$PHASE" = "Running" ]; then
    echo "  Pod is Running!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "ERROR: Vault pod not Running after 5 minutes!"
    kubectl describe pod -n "$VAULT_NS" "$VAULT_POD" | tail -10
    exit 1
  fi
  sleep 10
done

# ── Check if already initialized ──────────────────────────────────────────
INIT_STATUS=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault status -format=json 2>/dev/null || echo '{"initialized":false}')
ALREADY_INIT=$(echo "$INIT_STATUS" | jq -r '.initialized // false')

if [ "$ALREADY_INIT" == "true" ]; then
  echo ">>> [SKIP] Vault already initialized. Unsealing if needed..."
  SEALED=$(echo "$INIT_STATUS" | jq -r '.sealed // false')
  if [ "$SEALED" == "true" ]; then
    UNSEAL_KEY=$(aws ssm get-parameter --name "$SSM_PREFIX/vault-unseal-key" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "")
    if [ -n "$UNSEAL_KEY" ]; then
      kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault operator unseal "$UNSEAL_KEY"
    else
      echo "ERROR: Vault sealed but no unseal key in SSM!"
      exit 1
    fi
  fi
  exit 0
fi

# ── Init Vault (KMS auto-unseal — không dùng key-shares/threshold) ───────
echo ">>> [2/9] Initializing Vault (KMS auto-unseal)..."
INIT_JSON=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault operator init -format=json)

UNSEAL_KEY=$(echo "$INIT_JSON" | jq -r '.unseal_keys_b64[0] // "auto-unseal-kms"')
ROOT_TOKEN=$(echo "$INIT_JSON" | jq -r '.root_token')

echo ">>> [3/9] Storing root token + unseal key marker in AWS SSM..."
aws ssm put-parameter --name "$SSM_PREFIX/vault-unseal-key" \
  --value "$UNSEAL_KEY" --type SecureString --overwrite --region "$REGION"

aws ssm put-parameter --name "$SSM_PREFIX/vault-root-token" \
  --value "$ROOT_TOKEN" --type SecureString --overwrite --region "$REGION"

# KMS auto-unseal: Vault tự unseal qua AWS KMS, không cần unseal thủ công
echo ">>> [4/9] Verifying Vault auto-unseal via KMS..."
SEALED_AFTER_INIT=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault status -format=json | jq -r '.sealed // false')
if [ "$SEALED_AFTER_INIT" == "true" ]; then
  echo "ERROR: Vault still sealed after KMS auto-unseal! Check IAM/kms_key_id."
  exit 1
else
  echo "  Vault is UNSEALED automatically via KMS ✅"
fi

# ── Enable secret engine + auth ───────────────────────────────────────────
echo ">>> [5/9] Enabling KV secret engine..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault secrets enable -path=secret kv-v2 2>/dev/null || true

echo ">>> [6/9] Enabling Kubernetes auth..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault auth enable kubernetes 2>/dev/null || true

# ── Generate & store secrets ─────────────────────────────────────────────
echo ">>> [7/9] Generating random secrets..."
POSTGRES_PASS=$(openssl rand -base64 24 | tr -d '=/+' | cut -c1-24)
JWT_SECRET=$(openssl rand -base64 48 | tr -d '=/+')
GRAFANA_PASS=$(openssl rand -base64 16 | tr -d '=/+' | cut -c1-16)

echo ">>> [7/9] Storing secrets in Vault..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault kv put secret/postgres password="$POSTGRES_PASS"

kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault kv put secret/jwt secret="$JWT_SECRET"

kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault kv put secret/grafana admin_password="$GRAFANA_PASS"

kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault kv put secret/database url="postgresql://postgres:${POSTGRES_PASS}@postgres:5432/shopdb?schema=public"

# ── Store passwords in SSM (để Terraform/Helm reference sau) ──────────────
echo ">>> [7b] Storing passwords in AWS SSM for External Secrets..."
aws ssm put-parameter --name "$SSM_PREFIX/postgres-password" \
  --value "$POSTGRES_PASS" --type SecureString --overwrite --region "$REGION"
aws ssm put-parameter --name "$SSM_PREFIX/jwt-secret" \
  --value "$JWT_SECRET" --type SecureString --overwrite --region "$REGION"
aws ssm put-parameter --name "$SSM_PREFIX/grafana-password" \
  --value "$GRAFANA_PASS" --type SecureString --overwrite --region "$REGION"
aws ssm put-parameter --name "$SSM_PREFIX/database-url" \
  --value "postgresql://postgres:${POSTGRES_PASS}@postgres:5432/shopdb?schema=public" \
  --type SecureString --overwrite --region "$REGION"

# ── Configure K8s auth ────────────────────────────────────────────────────
echo ">>> [8/9] Configuring Kubernetes auth..."
SA_JWT=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
SA_CA=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
K8S_HOST=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- sh -c 'echo $KUBERNETES_PORT_443_TCP_ADDR')

kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT" \
  kubernetes_host="https://$K8S_HOST:443" \
  kubernetes_ca_cert="$SA_CA"

# ── Policy + Role ──────────────────────────────────────────────────────────
echo ">>> [9/9] Creating policy + auth role..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  sh -c 'cat > /tmp/techshop-policy.hcl << EOF
path "secret/data/postgres" { capabilities = ["read"] }
path "secret/data/jwt"      { capabilities = ["read"] }
path "secret/data/grafana"  { capabilities = ["read"] }
path "secret/data/database" { capabilities = ["read"] }
EOF
vault policy write techshop /tmp/techshop-policy.hcl'

kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault write auth/kubernetes/role/techshop \
  bound_service_account_names="*" \
  bound_service_account_namespaces="techshop-dev,techshop-stg" \
  policies=techshop \
  ttl=24h

# ── Dynamic Database Secrets (Postgres) ───────────────────────────────────
# Lưu ý: postgres (techshop-dev) do ArgoCD deploy SAU terraform apply, nên
# bước này chỉ thử NHANH 1 lần. Nếu postgres chưa lên (luôn đúng ở lần apply
# đầu) → bỏ qua, terraform_data.configure_vault_db sẽ tự cấu hình sau khi
# ArgoCD sync (chờ postgres Running rồi ghi config + test).
echo ">>> [9b] Enabling Dynamic Database Secrets (fast attempt)..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault secrets enable database 2>/dev/null || true

if kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault write database/config/techshop-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="techshop-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgres.techshop-dev.svc.cluster.local:5432/shopdb?sslmode=disable" \
    username="postgres" \
    password="$POSTGRES_PASS" >/dev/null 2>&1; then
  echo "  ✅ database/config/techshop-postgres configured"
  kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
    vault write database/roles/techshop-role \
    db_name="techshop-postgres" \
    creation_statements='CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT CONNECT ON DATABASE shopdb TO "{{name}}"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "{{name}}";' \
    default_ttl="1h" \
    max_ttl="24h" >/dev/null 2>&1 && echo "  ✅ database/roles/techshop-role configured"
else
  echo "  ⏭️  postgres chưa lên (bình thường ở apply đầu) — configure-vault-db.sh sẽ cấu hình sau khi ArgoCD sync."
fi

echo ""
echo "============================================"
echo "✅ Vault initialized and configured!"
echo "   Postgres password: $POSTGRES_PASS"
echo "   JWT secret:       ${JWT_SECRET:0:16}..."
echo "   Grafana password: $GRAFANA_PASS"
echo "============================================"
echo ""
echo "Unseal key & root token stored in AWS SSM:"
echo "  /techshop/vault-unseal-key"
echo "  /techshop/vault-root-token"
