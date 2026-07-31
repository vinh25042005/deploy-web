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

## Files đã sửa

| File | Thay đổi |
|---|---|
| `terraform/live/main.tf` | Thêm `wait = false` cho vault & external_secrets, bỏ nodeSelector, sửa apply_manifests chờ webhook, thêm helm_release.ebs_csi_driver, sửa set syntax |
| `terraform/modules/compute/main.tf` | Thêm `ec2:DescribeAvailabilityZones`, `ec2:DescribeSnapshots` vào IAM policy |
| `ansible/roles/common/tasks/main.yml` | Thêm task kill unattended-upgrades + xoá apt locks |
