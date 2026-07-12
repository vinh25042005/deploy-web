# Ansible — Cài Monitoring Stack (Prometheus + Grafana + Node Exporter)

## Cấu trúc

```
ansible/
├── ansible.cfg                 # Config: inventory, roles_path, vault
├── inventory/
│   ├── hosts.yml               # 1 VM nhóm monitoring
│   └── group_vars/all/
│       ├── vars.yml            # Biến thường (ports, versions...)
│       └── vault.yml           # 🔒 Secrets (Grafana password) - AES256
├── playbooks/
│   └── monitoring.yml          # Playbook chính
└── roles/monitoring/
    ├── defaults/main.yml
    ├── tasks/main.yml          # 6 steps: install → config → start → verify
    ├── handlers/main.yml       # Restart services
    └── templates/
        ├── prometheus.yml.j2   # Scrape config
        ├── grafana.ini.j2      # Grafana settings
        └── datasources.yml.j2  # Auto-connect Prometheus
```

## Quick Start

### 1. Sửa IP VM
```yaml
# inventory/group_vars/all/vars.yml
monitoring_host: 10.20.1.100   # ← IP thật
```

### 2. Tạo vault password
```bash
echo "my-password" > .vault_pass && chmod 600 .vault_pass
```

### 3. Chạy
```bash
ansible-playbook playbooks/monitoring.yml
```

### 4. Truy cập
| Service | URL |
|---|---|
| Prometheus | `http://<IP>:9090` |
| Grafana | `http://<IP>:3000` (admin / vault password) |
| Node Exporter | `http://<IP>:9100/metrics` |

## Monitoring Stack

```
┌──────────────────────────────────┐
│           VM monitoring           │
│  Grafana:3000 ← Prometheus:9090  │
│                      ↓ scrape    │
│               Node Exporter:9100 │
│               (CPU,RAM,disk,net) │
└──────────────────────────────────┘
```
