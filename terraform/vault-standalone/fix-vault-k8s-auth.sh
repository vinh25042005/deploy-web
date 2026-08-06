#!/usr/bin/env bash
# =============================================================================
# fix-vault-k8s-auth.sh — (Re)fix k8s auth + AppRole cho Vault standalone + least-privilege CI
#
# Giải quyết 2 vấn đề đã gặp:
#   1) 403 "permission denied" khi k8s auth login — nguyên nhân `token_reviewer_jwt`
#      (projected SA token ~1h) hết hạn → TokenReview fail → MỌI login MỚI fail (403),
#      trong khi token đã cấp (24h) vẫn renew → pod restart / CI build đều chết.
#      Fix: SA chuyên dụng `vault-auth` + token NON-EXPIRING (legacy secret) làm
#      token_reviewer_jwt.
#   2) Least-privilege CI: policy `techshop-ci` (CHỈ secret/data/ci/* + cosign) tách
#      khỏi policy app `techshop` (chỉ postgres/jwt/grafana/database) → pod app bị
#      chiếm KHÔNG đọc được CI credentials.
#   3) AppRole cho Jenkins (Hashicorp Vault Plugin): role `jenkins` gắn policy
#      `techshop-ci`, role_id/secret_id lưu AWS SSM.
#
# IDEMPOTENT — chạy lại thoải mái. Yêu cầu: kubectl (kubeconfig), aws cli (SSM),
# curl, python3.
#
# Usage: fix-vault-k8s-auth.sh <aws-region> [VAULT_ADDR] [K8S_API]
#   VD:   bash fix-vault-k8s-auth.sh ap-southeast-1
# =============================================================================
set -euo pipefail

REGION="${1:-ap-southeast-1}"
VAULT_ADDR="${VAULT_ADDR:-https://52.221.18.86:8200}"
K8S_API="${K8S_API:-$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')}"
SSM="/techshop"
VAULT_NS="vault"
AUTH_SA="vault-auth"

echo ">>> [1/7] Root token từ SSM ($SSM/vault-root-token)..."
ROOT=$(aws ssm get-parameter --name "$SSM/vault-root-token" --with-decryption \
  --region "$REGION" --query Parameter.Value --output text)

echo ">>> [2/7] Đảm bảo SA $AUTH_SA + ClusterRoleBinding auth-delegator..."
kubectl create sa "$AUTH_SA" -n "$VAULT_NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount="$VAULT_NS:$AUTH_SA" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo ">>> [3/7] Lấy token LONG-LIVED cho $AUTH_SA (token_reviewer_jwt)..."
# Ưu tiên legacy secret (non-expiring). Nếu cluster tắt auto-gen → fallback projected 8760h.
kubectl apply -f - <<EOF >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: $AUTH_SA-token
  namespace: $VAULT_NS
  annotations:
    kubernetes.io/service-account.name: $AUTH_SA
type: kubernetes.io/service-account-token
EOF
sleep 2
REVIEWER_JWT=$(kubectl get secret "$AUTH_SA-token" -n "$VAULT_NS" \
  -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
if [ -z "$REVIEWER_JWT" ]; then
  REVIEWER_JWT=$(kubectl create token "$AUTH_SA" -n "$VAULT_NS" --duration=8760h)
  echo "  ⚠️  Legacy token không sinh được — dùng projected 8760h (sẽ hết hạn sau 1 năm, re-run để refresh)"
else
  echo "  ✅ Legacy token non-expiring (không có exp)"
fi

echo ">>> [4/7] Ghi auth/kubernetes/config (kubernetes_host + CA + reviewer JWT)..."
CA_PEM=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)
PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"kubernetes_host":sys.argv[1],"kubernetes_ca_cert":sys.argv[2],"token_reviewer_jwt":sys.argv[3]}))' \
  "$K8S_API" "$CA_PEM" "$REVIEWER_JWT")
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d "$PAYLOAD" "$VAULT_ADDR/v1/auth/kubernetes/config" >/dev/null
echo "  ✅ kubernetes_host=$K8S_API"

echo ">>> [5/7] Least-privilege: policy techshop-ci (CI) vs techshop (app)..."
CI_POLICY='path "secret/data/ci/github"    { capabilities = ["read"] }
path "secret/data/ci/dockerhub" { capabilities = ["read"] }
path "secret/data/ci/sonar"     { capabilities = ["read"] }
path "secret/data/ci/cosign"    { capabilities = ["read"] }
path "secret/data/cosign"       { capabilities = ["read"] }'
APP_POLICY='path "secret/data/postgres"    { capabilities = ["read"] }
path "secret/data/jwt"         { capabilities = ["read"] }
path "secret/data/grafana"     { capabilities = ["read"] }
path "secret/data/database"    { capabilities = ["read"] }'
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"policy":sys.argv[1]}))' "$CI_POLICY")" \
  "$VAULT_ADDR/v1/sys/policies/acl/techshop-ci" >/dev/null
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"policy":sys.argv[1]}))' "$APP_POLICY")" \
  "$VAULT_ADDR/v1/sys/policies/acl/techshop" >/dev/null
# Role k8s auth: CI chỉ SA jenkins-ci (techshop-dev); app vẫn dùng role techshop
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d '{"bound_service_account_names":["jenkins-ci"],"bound_service_account_namespaces":["techshop-dev"],"policies":["techshop-ci"],"ttl":"1h"}' \
  "$VAULT_ADDR/v1/auth/kubernetes/role/techshop-jenkins" >/dev/null
echo "  ✅ role techshop-jenkins → techshop-ci; policy techshop chỉ còn secret app"

echo ">>> [6/7] AppRole cho Jenkins (Hashicorp Vault Plugin) + audit log..."
# AppRole auth + role jenkins (policy techshop-ci, secret_id non-expiring)
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d '{"type":"approle"}' "$VAULT_ADDR/v1/sys/auth/approle" -o /dev/null || true
curl -sk -X POST -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d '{"token_policies":["techshop-ci"],"token_ttl":"1h","token_max_ttl":"24h","secret_id_ttl":"0","secret_id_num_uses":"0"}' \
  "$VAULT_ADDR/v1/auth/approle/role/jenkins" -o /dev/null || true
ROLE_ID=$(curl -sk -H "X-Vault-Token: $ROOT" "$VAULT_ADDR/v1/auth/approle/role/jenkins/role-id" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["role_id"])')
SECRET_ID=$(curl -sk -X POST -H "X-Vault-Token: $ROOT" "$VAULT_ADDR/v1/auth/approle/role/jenkins/secret-id" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["secret_id"])')
aws ssm put-parameter --name "$SSM/jenkins-approle-role-id" --value "$ROLE_ID" --type SecureString --overwrite --region "$REGION" >/dev/null
aws ssm put-parameter --name "$SSM/jenkins-approle-secret-id" --value "$SECRET_ID" --type SecureString --overwrite --region "$REGION" >/dev/null
echo "  ✅ AppRole jenkins (role_id/secret_id → SSM $SSM/jenkins-approle-*)"
# Audit log (bắt buộc để phát hiện đọc secret bất thường)
curl -sk -X PUT -H "X-Vault-Token: $ROOT" -H "Content-Type: application/json" \
  -d '{"type":"file","options":{"file_path":"/opt/vault/audit/audit.log"}}' \
  "$VAULT_ADDR/v1/sys/audit/file" -o /dev/null || true
echo "  ✅ file audit enabled (/opt/vault/audit/audit.log trên Vault VM)"

echo ">>> [7/7] Test: login k8s (jenkins-ci) + login AppRole + đọc secret/ci..."
JWT=$(kubectl create token jenkins-ci -n techshop-dev --audience=vault 2>&1 | tail -1)
curl -sk -X POST "$VAULT_ADDR/v1/auth/kubernetes/login" -d "{\"role\":\"techshop-jenkins\",\"jwt\":\"$JWT\"}" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  ✅ k8s jenkins-ci login OK" if d.get("auth") else "  ❌ "+json.dumps(d.get("errors")))'
curl -sk -X POST -H "Content-Type: application/json" "$VAULT_ADDR/v1/auth/approle/login" \
  -d "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  ✅ AppRole login OK" if d.get("auth") else "  ❌ "+json.dumps(d.get("errors")))'

echo ""
echo "✅ Hoàn tất. Lưu ý phía Jenkins:"
echo "   - Cài plugin: hashicorp-vault-plugin + hashicorp-vault-pipeline"
echo "   - Credential AppRole 'vault-approle-jenkins' (role_id/secret_id từ SSM)"
echo "   - Import CA Vault vào JVM truststore container:"
echo "       sudo docker cp /jenkins-home/vault-ca.crt jenkins:/tmp/ca.crt"
echo "       sudo docker exec -u root jenkins keytool -importcert -noprompt -alias vault-ca \\"
echo "         -file /tmp/ca.crt -keystore /opt/java/openjdk/lib/security/cacerts -storepass changeit"
echo "   - Rồi restart Jenkins (nạp lại truststore)."
unset ROOT REVIEWER_JWT CA_PEM PAYLOAD ROLE_ID SECRET_ID
