## Task: Ansible — Inventory, Playbook, Role, Vault: Cài Monitoring Stack lên VM

- **Intern**: Nguyễn Quang Vinh
- **Phase / Week / Day**: `Phase 2 / Week 4 / Day 3`
- **Branch**: `phase-2/week-4/day-3-ansible`
- **Link GitHub**: https://github.com/vinh25042005/deploy-web/tree/phase-2/week-4/day-3-ansible
- **Submitted at**: `2026-07-12`
- **Time spent**: `~4h`

## 1. Mục tiêu

- Dùng **Terraform** tạo 1 EC2 VM trên AWS (Ubuntu 22.04, t3.micro, public IP)
- Dùng **Ansible** cài monitoring stack gồm Prometheus + Grafana + Node Exporter lên VM
- Sử dụng **Ansible Vault** mã hóa mật khẩu Grafana bằng AES256
- Tự động import dashboard Node Exporter Full (31 panels) vào Grafana

## 2. Cách chạy

```bash
# 1. Clone repo + checkout branch
git clone https://github.com/vinh25042005/deploy-web.git
cd deploy-web
git checkout phase-2/week-4/day-3-ansible

# 2. Sửa config nếu cần (region, key pair, instance type)
vim config.sh

# 3. Chạy 1 lệnh duy nhất
./run.sh
```

**Luồng chạy:**
```
terraform apply → tạo EC2 + SG (port 22, 9090, 3000, 9100)
       ↓
   đợi SSH sẵn sàng (retry 30 lần × 10s)
       ↓
ansible-playbook → cài Prometheus + Grafana + Node Exporter
       ↓
   import dashboard → verify tất cả services
```

**Hoặc chạy từng bước thủ công:**

```bash
# Step 1: Tạo VM
cd terraform && terraform init && terraform apply -auto-approve
VM_IP=$(terraform output -raw public_ip)

# Step 2: Đợi SSH
ssh -o StrictHostKeyChecking=no -i ~/.ssh/techshop-key.pem ubuntu@$VM_IP "echo OK"

# Step 3: Cài monitoring
cd ../ansible
ansible-playbook playbooks/monitoring.yml -e "monitoring_host=$VM_IP"

# Step 4: Verify
curl http://$VM_IP:9090/-/ready      # Prometheus
curl http://$VM_IP:3000/api/health   # Grafana
curl http://$VM_IP:9100/metrics      # Node Exporter

# Destroy khi xong
terraform -chdir=terraform destroy -auto-approve
```

## 3. Kết quả

### Ansible run: `ok=23  changed=13  failed=0`

| Thành phần | Trạng thái | Chi tiết |
|---|---|---|
| Prometheus | ✅ `active` | `http://<IP>:9090` — "Prometheus is Ready" |
| Grafana | ✅ `active` | `http://<IP>:3000` — `database: ok`, version 13.1.0 |
| Node Exporter | ✅ `active` | `http://<IP>:9100/metrics` — đang serve metrics |
| Dashboard | ✅ Imported | Node Exporter Full — 31 panels, auto-connect Prometheus |

### Screenshots (`./screenshots/`):

| File | Nội dung |
|---|---|
| `01-services.txt` | 3 services `active` |
| `02-prometheus.txt` | `Prometheus is Ready.` |
| `03-grafana-api.txt` | `{"database": "ok", "version": "13.1.0"}` |
| `04-node-exporter.txt` | Metrics output |
| `05-ansible-recap.txt` | `ok=23 failed=0` |
| `06-grafana-dashboard.png` | Dashboard Node Exporter Full |
| `07-prometheus-ui.png` | Prometheus Web UI |
| `08-grafana-datasources.png` | Prometheus datasource connected |

## 4. Khó khăn & cách giải quyết

- **Grafana không có trong default Ubuntu repo** → Thêm Grafana APT repository (`apt_key` + `apt_repository`) trước khi `apt install grafana`
- **`set` block trong helm_release bị deprecated với Terraform 1.15** → Chuyển sang `set = [{name, value, type}]` (argument thay vì block)
- **`~` trong path không được expand bởi Terraform provider** → Dùng `pathexpand(var.kubeconfig_path)` trong provider config
- **Kubeconfig lưu vào SSM bị vượt 4KB** → Nén bằng `gzip | base64 -w0` trước khi `put-parameter`
- **Dashboard trống sau khi cài Grafana** → Thêm task `uri` gọi Grafana API import dashboard ID 1860 tự động
