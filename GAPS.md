# TechShop — Phân tích thiếu sót so với yêu cầu Capstone

> So sánh project hiện tại với yêu cầu capstone + Week 3 + Week 4
> Chỉ ghi nhận, KHÔNG sửa code

---

## Yêu cầu Capstone Block

| # | Yêu cầu | Trạng thái | Ghi chú |
|---|---------|-----------|---------|
| 1 | 1 app HTTP backend (Express) | ✅ | backend/ (Express + TypeScript + Prisma) |
| 2 | Postgres trên K8s (StatefulSet + PVC) | ✅ | Deployment + PVC 10Gi + backup S3 |
| 3 | Ingress + TLS (cert-manager + selfsigned) | ✅ | Đã thêm cert-manager Helm dependency + selfsigned ClusterIssuer + Certificate tự động renew 90 ngày |
| 4 | Helm chart tự viết | ✅ | helm/techshop/ — đầy đủ templates |
| 5 | Monitoring (kube-prometheus-stack) | ✅ | Prometheus + Grafana + Alertmanager + Loki + Promtail |
| 6 | CI: build + scan + sign image (cosign keyless) | ✅ | ci.yml: lint → test → build → trivy → syft → cosign |
| 7 | CD: ArgoCD hoặc helm upgrade từ GitHub Actions | ✅ | deploy-gke.yml: verify signature → kubectl set image |
| 8 | Repo có 2 thư mục: charts/\<name\> + infra/ | ⚠️ | Hiện tại: helm/techshop/ + terraform/. Nên rename helm/techshop → charts/techshop, terraform/ → infra/ |
| 9 | README chuẩn + sơ đồ kiến trúc | ✅ | Đã có README.md + diagram |
| 10 | Video demo < 5 phút | ❌ | Chưa có |
| 11 | RUNBOOK.md | ❌ | Chưa có |
| 12 | Reproducibility (mentor làm theo README có ra không) | ⚠️ | Cần kiểm tra lại. IP thay đổi sau destroy, cần update /etc/hosts. Secret AWS cần setup thủ công |

---

## Week 3 — Kubernetes Deep Dive

| # | Lab / Yêu cầu | Trạng thái | Ghi chú |
|---|--------------|-----------|---------|
| 1 | Kiến trúc k8s, k3d cluster | ✅ | Dùng kubeadm thay vì k3d |
| 2 | Deployment, Service, Ingress | ✅ | backend/frontend/postgres deploy + ingress |
| 3 | ConfigMap, Secret, env injection | ✅ | configmap.yaml + secret.yaml |
| 4 | Storage: PV, PVC, StorageClass | ✅ | storageclass.yaml + postgres-pvc.yaml |
| 5 | RBAC, ServiceAccount, NetworkPolicy | ✅ | rbac.yaml (readonly) + networkpolicy.yaml |
| 6 | Helm chart | ✅ | helm/techshop/ |

---

## Week 4 — IaC nâng cao + Monitoring + Security

| # | Lab / Yêu cầu | Trạng thái | Ghi chú |
|---|--------------|-----------|---------|
| 1 | Terraform module + remote backend (S3+DDB) | ✅ | modules/network, compute, rancher + S3 backend |
| 2 | Terraform workspace, dependency graph | ✅ | Đã thêm DynamoDB lock (`techshop-tfstate-lock`) |
| 3 | Ansible: inventory, playbook, role, vault | ✅ | Đã có ansible-vault (`vars/secrets.yml`) mã hóa passwords |
| 4 | Prometheus + Grafana + Loki trên k8s | ✅ | Qua Helm dependency |
| 5 | Trivy + cosign + SBOM | ✅ | CI workflow |
| 6 | Module dùng được ở 2 env, state tách riêng | ⚠️ | Có envs/dev + envs/stg nhưng chưa dùng terraform workspace thực sự |
| 7 | Grafana dashboard sống, có alert test fire được | ⚠️ | Dashboard Node Exporter có, alert PodRestartHigh có nhưng chưa test fire |
| 8 | CD pipeline reject image chưa sign | ✅ | verify-signatures job trong deploy-gke.yml |

---

## Các thiếu sót cần bổ sung

### Ưu tiên CAO

| # | Thiếu sót | Đề xuất |
|---|-----------|---------|
| 1 | **RUNBOOK.md** | Tạo file mô tả "khi prod down phải làm gì": kiểm tra node, pod, restart, rollback helm, restore DB từ S3 |
| 2 | **Video demo** | Quay màn hình < 5 phút: destroy → deploy → show web + grafana + rancher |
| 3 | **cert-manager** | ✅ | Đã thêm cert-manager + selfsigned ClusterIssuer + Certificate tự động (templates/cert-manager.yaml) |

### Ưu tiên TRUNG BÌNH

| # | Thiếu sót | Đề xuất |
|---|-----------|---------|
| 4 | **Rename folders** | helm/techshop → charts/techshop, terraform/ → infra/ |
| 5 | **Terraform workspace** | Sử dụng terraform workspace cho dev/stg thay vì chỉ có locals |
| 6 | **env values structure** | values-dev.yaml, values-stg.yaml đã có nhưng chưa test với terraform workspace |
| 7 | **Loki app logs** | Loki đọc được log canary nhưng không đọc được log app (backend/frontend). Cần debug Promtail scrape config |
| 8 | **Alert test fire** | Kích hoạt alert PodRestartHigh thủ công để verify |
| 9 | **Grafana dashboard tự tạo** | Thêm dashboard custom cho app metrics (request rate, error rate) |

### Ưu tiên THẤP

| # | Thiếu sót | Đề xuất |
|---|-----------|---------|
| 10 | **imagePullSecret** | Thêm vào Helm chart để cluster pull được private GHCR images |
| 11 | **Resource quotas** | Thêm ResourceQuota cho namespace techshop |
| 12 | **PodDisruptionBudget** | Thêm PDB cho backend/frontend để đảm bảo availability khi upgrade |
| 13 | **Pre-commit hooks** | Thêm lint + test trước khi commit |
| 14 | **ArgoCD** | Capstone yêu cầu ArgoCD HOẶC helm upgrade. Hiện tại dùng helm upgrade, có thể bổ sung ArgoCD sau |
| 15 | **Rancher import** | Hiện tại import cluster vào Rancher thủ công. Có thể tự động hóa qua API |

---

## Đã hoàn thành so với báo cáo trước

| # | Mục | Trạng thái |
|---|-----|-----------|
| 4 | **DynamoDB lock** | ✅ Đã thêm `dynamodb_table = "techshop-tfstate-lock"` vào backend config |
| 5 | **Terraform state lock** | ✅ DynamoDB table đã tồn tại, backend đã cấu hình |
| 6 | **Ansible vault** | ✅ Đã tạo `ansible/vars/secrets.yml` (AES256) + `.vault_pass` (gitignored) |
| 7 | **cert-manager** | ✅ Đã thêm cert-manager Helm dependency + ClusterIssuer + Certificate tự động renew |
