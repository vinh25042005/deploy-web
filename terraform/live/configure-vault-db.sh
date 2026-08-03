#!/usr/bin/env bash
# =============================================================================
# configure-vault-db.sh — Cấu hình Dynamic Database Secrets (Postgres)
#
# Tại sao cần script riêng?
#   vault-init.sh chạy TRONG terraform apply, nhưng postgres (techshop-stg)
#   do ArgoCD deploy SAU apply. Vì vậy vault-init không kết nối được postgres.
#   Script này được terraform_data.configure_vault_db gọi Ở CUỐI apply:
#   chờ postgres lên (ArgoCD sync xong) rồi ghi database/config + role.
#
# Usage: configure-vault-db.sh <aws-region>
#   env: DB_WAIT_SECONDS (mặc định 600 = 10 phút chờ postgres)
# =============================================================================
set -euo pipefail

REGION="${1:-ap-southeast-1}"
VAULT_NS="vault"
VAULT_POD="vault-0"
SSM_PREFIX="/techshop"
POSTGRES_NS="techshop-stg"   # techshop-dev đã tắt; postgres giờ nằm ở stg
WAIT_SECONDS="${DB_WAIT_SECONDS:-600}"

# ── Đảm bảo ArgoCD sync ĐÚNG HEAD (phòng repo-server cache stale) ──────────
#   Bug từng gặp: repo-server giữ branch week-6-argo-rollouts ở commit CŨ →
#   ArgoCD deploy chart cũ (loki/ebs-csi/alertmanager) → prune xoá EBS CSI RBAC
#   (kube-system) → postgres không lên. Restart repo-server + force sync về HEAD.
echo ">>> [db] Restart argocd-repo-server (clear cache)..."
kubectl rollout restart deployment/argocd-repo-server -n argocd 2>/dev/null || true
sleep 15
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s 2>/dev/null || true

echo ">>> [db] Force ArgoCD sync techshop-stg về HEAD (week-6-argo-rollouts)..."
kubectl patch application techshop-stg -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"week-6-argo-rollouts","prune":true,"resources":null}}}' 2>/dev/null || true

echo ">>> [db] Chờ ArgoCD sync hoàn tất (tối đa 240s)..."
for i in $(seq 1 24); do
  SYNC_REV=$(kubectl get application techshop-stg -n argocd -o jsonpath='{.status.operationState.syncResult.revision}' 2>/dev/null || echo "")
  # HEAD mong đợi: revision của nhánh week-6-argo-rollouts. Nếu sync đúng, tiếp tục.
  if kubectl get application techshop-stg -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null | grep -q Synced; then
    echo "  ✅ ArgoCD techshop-stg synced (rev=${SYNC_REV})"
    break
  fi
  sleep 10
done
echo "  → ArgoCD đang sync revision: ${SYNC_REV:-<đang cập nhật>}"

echo ">>> [db] Chờ ArgoCD deploy postgres ($POSTGRES_NS)..."
POSTGRES_READY=0
for i in $(seq 1 $((WAIT_SECONDS / 10))); do
  PHASE=$(kubectl get pod postgres-0 -n "$POSTGRES_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$PHASE" = "Running" ]; then
    echo "  ✅ postgres Running sau $((i * 10))s"
    POSTGRES_READY=1
    break
  fi
  sleep 10
done

if [ "$POSTGRES_READY" != "1" ]; then
  echo ""
  echo "❌ postgres chưa Running sau ${WAIT_SECONDS}s. Kiểm tra ArgoCD apps:"
  echo "    kubectl get applications -n argocd"
  echo "    kubectl get pods -n techshop-stg | grep postgres"
  echo ""
  echo "   Khi postgres lên, chạy lại apply để retry:"
  echo "    terraform apply -replace=terraform_data.configure_vault_db -auto-approve"
  exit 1
fi

echo ">>> [db] Lấy ROOT_TOKEN + POSTGRES_PASS từ AWS SSM..."
ROOT_TOKEN=$(aws ssm get-parameter --name "$SSM_PREFIX/vault-root-token" --with-decryption --region "$REGION" --query Parameter.Value --output text)
POSTGRES_PASS=$(aws ssm get-parameter --name "$SSM_PREFIX/postgres-password" --with-decryption --region "$REGION" --query Parameter.Value --output text)

echo ">>> [db] Chờ Vault unsealed..."
for i in $(seq 1 30); do
  SEALED=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "true")
  if [ "$SEALED" = "false" ]; then
    echo "  ✅ Vault unsealed"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Vault vẫn sealed sau 5 phút. Kiểm tra KMS auto-unseal!"
    exit 1
  fi
  sleep 10
done

echo ">>> [db] Ghi database/config/techshop-postgres..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault write database/config/techshop-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="techshop-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.techshop-stg.svc.cluster.local:5432/shopdb?sslmode=disable" \
  username="postgres" \
  password="$POSTGRES_PASS"

echo ">>> [db] Ghi database/roles/techshop-role..."
kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault write database/roles/techshop-role \
  db_name="techshop-postgres" \
  creation_statements='CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT CONNECT ON DATABASE shopdb TO "{{name}}"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "{{name}}";' \
  default_ttl="1h" \
  max_ttl="24h"

echo ">>> [db] Test dynamic DB credentials..."
DB_USER=$(kubectl exec -n "$VAULT_NS" "$VAULT_POD" -- env VAULT_TOKEN="$ROOT_TOKEN" \
  vault read -format=json database/creds/techshop-role 2>/dev/null | jq -r '.data.username')
echo "  ✅ Dynamic DB OK: $DB_USER"

echo ""
echo "✅ configure-vault-db hoàn tất — Dynamic Database Secrets đã hoạt động."
