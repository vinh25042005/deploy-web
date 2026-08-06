# Terraform Fixes Log

## 1. `terraform destroy` treo do `helm_release` không có `wait = false`

**Lỗi**: Khi chạy `terraform destroy`, `helm_release.external_secrets` và `helm_release.vault` treo mãi vì webhook CRD không phản hồi khi cluster đang shutdown.

**Fix**: Thêm `wait = false` vào `helm_release` resources:

- `main.tf` — `helm_release.vault`: thêm `wait = false`
- `main.tf` — `helm_release.external_secrets`: thêm `wait = false`

## 2. Vault pod không schedule được do `nodeSelector`

**Lỗi**: Vault pod có `nodeSelector: topology.kubernetes.io/zone=ap-southeast-1a` nhưng worker nodes (self-managed K8s trên EC2) không có label `topology.kubernetes.io/zone`.

```
0/4 nodes available: 2 node(s) didn't match Pod's node affinity/selector
```

**Fix**: Xoá `nodeSelector` khỏi Vault Helm values trong `main.tf`.

## 3. `terraform_data.apply_manifests` lỗi webhook external-secrets chưa ready

**Lỗi**: `apply_manifests` chạy ngay sau `helm_release.external_secrets` (có `wait = false`) nên webhook pod chưa kịp Ready. Kết quả: `kubectl apply` bị lỗi `connection refused` khi gọi webhook.

**Fix**: Thay vì `kubectl apply` trực tiếp, thêm vòng lặp chờ webhook pod Ready trước khi apply manifests.

## 4. Ansible apt lock conflict (unattended-upgrades)

**Lỗi**: EC2 instance vừa boot có `unattended-upgrades` chạy ngầm, giữ lock apt. Ansible chạy `apt-get update` / `apt-get install` bị lỗi `Could not get lock`.

**Fix**: Thêm task dọn dẹp apt lock ở đầu `ansible/roles/common/tasks/main.yml`:
- Kill `unattended-upgrades`
- Kill các process `apt-get` / `apt` còn sót
- Xoá các lock files

## 5. Ansible cert-manager task timeout (retry chain dài)

**Lỗi**: Task `Install cert-manager` download từ GitHub releases và chờ webhook 3 phút — đôi khi timeout. Khi fail, Ansible retry TOÀN BỘ playbook (5 plays), mất ~15-20 phút mỗi lần.

**Note**: Không có fix triệt để (vì đây là network-dependent issue). Retry chain vẫn hoạt động nhưng tốn thời gian. Có thể cải thiện bằng cách tách post-deploy playbook riêng biệt.

## 6. `terraform_data.vault_init` TLS handshake timeout

**Lỗi**: Bước 8/9 của vault-init.sh (`Configuring Kubernetes auth`) bị `TLS handshake timeout` khi gọi K8s API.

**Note**: Lỗi tạm thời (transient). Chạy lại `terraform apply` lần 2 → vault detect đã init → skip → success.

## 7. `terraform apply` syntax error — `set` block trong `helm_release`

**Lỗi**: Dùng `set { ... }` (block syntax) thay vì `set = [ { ... } ]` (argument syntax).
```
Blocks of type "set" are not expected here.
```

**Fix**: Đổi thành `set = [ { name = "...", value = "..." } ]`.

## 8. Vault KMS auto-unseal — init không được dùng `-key-shares`/`-key-threshold`

**Lỗi**: Sau khi thêm `seal "awskms"` vào Vault config, `vault operator init -key-shares=1 -key-threshold=1` báo:
```
* parameters secret_shares,secret_threshold not applicable to seal type awskms
```

**Fix** (`vault-init.sh`): Bỏ `-key-shares`/`-key-threshold` khi init. Với KMS auto-unseal:
- Không cần unseal thủ công — Vault tự unseal qua AWS KMS
- Bỏ bước unseal thủ công, thay bằng verify `sealed=false`

**Kết quả test**: Xóa pod `vault-0` → pod mới tự unseal qua KMS, không cần unseal thủ công ✅

## 9. K8s auth 403 — `token_reviewer_jwt` bị stale sau khi pod Vault restart

**Lỗi**: Pod postgres kẹt ở `Init:0/1` (vault-agent-init), log:
```
PUT http://vault.vault.svc:8200/v1/auth/kubernetes/login  Code: 403. Errors: * permission denied
```

**Nguyên nhân**: `auth/kubernetes/config` được ghi trong apply với `token_reviewer_jwt` của pod Vault lúc đó. Sau khi pod Vault bị xóa (test auto-unseal / node reboot), SA token đổi → JWT cũ bị API server từ chối → TokenReview fail → 403.

**Fix**: Ghi lại `auth/kubernetes/config` với `token_reviewer_jwt` + `kubernetes_ca_cert` hiện tại:
```
kubectl exec -n vault vault-0 -- env VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/config \
  token_reviewer_jwt="$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://10.96.0.1:443" \
  kubernetes_ca_cert="$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)"
```

## 10. ArgoCD prune xoá ClusterRole/CRB dùng chung — EBS CSI mất RBAC

**Lỗi**: Sau khi tắt `storage.ebsCSI` và ArgoCD prune, EBS CSI controller (kube-system) báo:
```
User "system:serviceaccount:kube-system:ebs-csi-controller-sa" cannot list persistentvolumeclaims / storageclasses / persistentvolumes / volumeattachments
```
→ Không provision được volume → postgres Pending.

**Nguyên nhân**: Helm chart `techshop` có subchart `aws-ebs-csi-driver` (điều kiện `storage.ebsCSI.enabled: true`). Khi ArgoCD deploy bản trùng trong `techshop-dev`, nó tạo ClusterRole/ClusterRoleBinding **cùng tên** với bản terraform cài trong `kube-system`. Khi tắt ebsCSI và ArgoCD prune → xoá luôn ClusterRole/CRB dùng chung → bản kube-system mất quyền.

**Fix**:
1. Tắt `storage.ebsCSI.enabled: false` trong `helm/techshop/values.yaml` (terraform sở hữu EBS CSI cluster-wide)
2. Re-install driver: `terraform apply -replace=helm_release.ebs_csi_driver -auto-approve`

## 11. StorageClass bị ArgoCD prune xoá (SC collision helm vs terraform)

**Lỗi**: PVC postgres báo `storageclass "techshop-ssm-waitforfirstconsumer" not found` — StorageClass biến mất.

**Nguyên nhân**: Helm chart `templates/storageclass.yaml` tạo SC **cùng tên** `techshop-ssm-waitforfirstconsumer` với terraform (`vault_storageclass`). Khi ebsCSI bị tắt, ArgoCD prune SC khỏi render → xoá luôn SC của terraform.

**Fix**: Tạo lại SC qua terraform:
```
terraform apply -target=terraform_data.vault_storageclass -replace=terraform_data.vault_storageclass -auto-approve
```

## 12. PVC bị "đóng băng" Immediate mode khi SC không tồn tại lúc tạo

**Lỗi**: Pod postgres báo `0/4 nodes are available: pod has unbound immediate PersistentVolumeClaims`.

**Nguyên nhân**: PVC được tạo khi SC chưa tồn tại → binding mode bị tính là `Immediate` (default) → scheduler từ chối schedule pod dù SC sau đó đã có.

**Fix**: Xoá STS + PVC để tạo lại (SC giờ đã tồn tại → dùng đúng `WaitForFirstConsumer`):
```
kubectl delete sts postgres -n techshop-stg
kubectl delete pvc pgdata-postgres-0 -n techshop-stg
# ArgoCD (selfHeal) tự tái tạo STS
kubectl patch application techshop-stg -n argocd --type merge \
  -p '{"operation":{"sync":{"revision":"<HASH>","prune":true,"syncStrategy":{"apply":{}}}}}'
```

## 13. Dynamic DB secrets không được cấu hình ở lần apply đầu

**Lỗi**: `vault read database/creds/techshop-role` → `failed to find entry for connection with name: "techshop-postgres"`.

**Nguyên nhân**: `vault-init.sh` chạy trong terraform apply, nhưng postgres (techshop-dev) do ArgoCD deploy **SAU** apply → Vault không verify được connection → `vault write database/config` fail.

**Fix (tự động hoá)**:
- `terraform/live/configure-vault-db.sh` + `terraform_data.configure_vault_db` (trong `main.tf`): resource chạy **cuối apply** (depends_on vault_init + apply_manifests + update_argocd_branch), chờ postgres `Running` (mặc định 600s) rồi ghi `database/config` + `database/roles` + test.
- `vault-init.sh` [9b]: chỉ thử nhanh 1 lần (không retry 180s vì postgres chưa bao giờ tồn tại lúc apply) — nếu chưa được thì bỏ qua, để `configure_vault_db` xử lý.
- Nếu postgres không lên sau 600s → resource fail → lần `terraform apply` sau tự retry.

## 14. Vault k8s auth 403 (token_reviewer_jwt hết hạn) + least-privilege CI + AppRole cho Jenkins

**Lỗi**: Mọi k8s auth login MỚI tới Vault bị `403 permission denied` (curl + vault CLI đều fail), dù token pod hợp lệ & role binding đúng. Pod cũ vẫn chạy (token 24h còn renew), nhưng pod restart / CI build mới → chết.

**Nguyên nhân**: `auth/kubernetes/config` có `token_reviewer_jwt_set=true` nhưng `token_reviewer_jwt` là projected SA token ~1h → hết hạn → Vault gọi TokenReview fail → 403 (Vault cố tình giấu lý do). Trùng failure mode mục #9 (bản in-cluster cũ).

**Fix (script tái lập: `terraform/vault-standalone/fix-vault-k8s-auth.sh`)**:
1. SA `vault-auth` (ns vault) + ClusterRoleBinding `system:auth-delegator` + **legacy token Secret non-expiring** → ghi lại `auth/kubernetes/config` (kubernetes_host + CA từ kubeconfig) làm `token_reviewer_jwt`.
2. **Least-privilege CI**: policy `techshop-ci` (chỉ `secret/data/ci/*` + cosign) tách khỏi policy `techshop` (app: postgres/jwt/grafana/database). Role `techshop-jenkins` → `techshop-ci`. → Pod app bị chiếm KHÔNG đọc được CI credentials.
3. **AppRole cho Jenkins** (Hashicorp Vault Plugin): role `jenkins` (policy `techshop-ci`), role_id/secret_id lưu SSM `/techshop/jenkins-approle-*`.
4. **Audit log** file: `/opt/vault/audit/audit.log`.

**Phía Jenkins** (đã làm):
- Cài `hashicorp-vault-plugin` + `hashicorp-vault-pipeline`; credential AppRole `vault-approle-jenkins`; global config vaultUrl/engineVersion.
- **Import CA Vault vào JVM truststore container** (bắt buộc — `skipSslVerification` global KHÔNG áp dụng cho AppRole login do bug mergeWithParent): `keytool -importcert -alias vault-ca` vào `/opt/java/openjdk/lib/security/cacerts` + restart Jenkins.
- `Jenkinsfile`: `environment { GITHUB_TOKEN = vault path: 'secret/ci/github', key: 'token' ... }` (plugin tự auth+mask). **GOTCHA kv-v2**: path KHÔNG chứa `/data/` (plugin tự thêm) — viết `secret/data/ci/github` → thành `secret/data/data/ci/github` → 403.

## Files đã sửa

| File | Thay đổi |
|---|---|
| `terraform/vault-standalone/fix-vault-k8s-auth.sh` | (mới) tái lập: SA vault-auth, refresh k8s config, policies, AppRole, audit, test |
| `Jenkinsfile` | Đọc secret qua HashiCorp Vault Plugin (`vault path:` + AppRole), bỏ vault CLI/kubectl create token |
| `terraform/live/main.tf` | Thêm `wait = false` cho vault & external_secrets, bỏ nodeSelector, sửa apply_manifests chờ webhook, thêm helm_release.ebs_csi_driver, sửa set syntax, thêm `seal "awskms"` |
| `terraform/modules/compute/main.tf` | Thêm `ec2:DescribeAvailabilityZones`, `ec2:DescribeSnapshots`, `kms:*` vào IAM policy |
| `ansible/roles/common/tasks/main.yml` | Thêm task kill unattended-upgrades + xoá apt locks |
| `terraform/live/vault-init.sh` | KMS auto-unseal (bỏ key-shares/unseal thủ công), DB config thử nhanh (configure_vault_db lo phần chính) |
| `terraform/live/configure-vault-db.sh` | Tự động cấu hình dynamic DB secrets sau khi ArgoCD deploy postgres |
| `terraform/live/main.tf` | Thêm `terraform_data.configure_vault_db` chạy cuối apply |
| `helm/techshop/values.yaml` | Tắt `storage.ebsCSI` (terraform sở hữu, tránh duplicate + prune) |
