# Ansible — Cài Monitoring Stack (Prometheus + Grafana + Node Exporter)

## Cấu trúc

```
├── run.sh                       # 🚀 1 lệnh: tạo VM + cài monitoring
├── terraform/                   # Tạo EC2 VM trên AWS
│   ├── main.tf                  # EC2 + Security Group
│   ├── variables.tf
│   └── outputs.tf               # Public IP
└── ansible/                     # Cài monitoring stack
    ├── ansible.cfg
    ├── inventory/
    │   ├── hosts.yml
    │   └── group_vars/all/
    │       ├── vars.yml
    │       └── vault.yml        🔒
    ├── playbooks/
    │   └── monitoring.yml
    └── roles/monitoring/
        ├── defaults/main.yml
        ├── tasks/main.yml
        ├── handlers/main.yml
        └── templates/
            ├── prometheus.yml.j2
            ├── grafana.ini.j2
            └── datasources.yml.j2
```

## Quick Start — 1 lệnh duy nhất

```bash
./run.sh
```

Luồng chạy:
```
terraform apply  →  tạo EC2 + SG (port 22, 9090, 3000, 9100)
       ↓
   đợi SSH sẵn sàng (retry 30 lần × 10s = 5 phút)
       ↓
ansible-playbook →  cài Prometheus + Grafana + Node Exporter
       ↓
   http://<IP>:3000  ← truy cập Grafana
```

## Chạy thủ công từng bước

```bash
# 1. Tạo VM
cd terraform && terraform apply -auto-approve
VM_IP=$(terraform output -raw public_ip)

# 2. Chạy Ansible
cd ../ansible
ansible-playbook playbooks/monitoring.yml -e "monitoring_host=$VM_IP"
```

## Truy cập

| Service | URL | Login |
|---|---|---|
| Prometheus | `http://<IP>:9090` | Không cần |
| Grafana | `http://<IP>:3000` | `admin` / (password trong vault.yml) |
| Node Exporter | `http://<IP>:9100/metrics` | Không cần |

## Monitoring Stack

```
┌──────────────────────────────────┐
│           EC2 monitoring          │
│  Grafana:3000 ← Prometheus:9090  │
│                      ↓ scrape    │
│               Node Exporter:9100 │
│               (CPU,RAM,disk,net) │
└──────────────────────────────────┘
```
