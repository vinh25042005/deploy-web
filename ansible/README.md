# Ansible — Lý thuyết & Chuẩn bị cho Day 3

## Ansible là gì?

Ansible là công cụ **tự động hóa cấu hình** (configuration management) và **orchestration**:
- Viết config 1 lần, chạy trên nhiều server
- Không cần cài agent trên máy đích (agentless)
- Kết nối qua SSH (Linux) hoặc WinRM (Windows)
- Dùng YAML cho playbook → dễ đọc, dễ học

## Tại sao dùng Ansible?

| Vấn đề | Không có Ansible | Có Ansible |
|---|---|---|
| Cài đặt phần mềm | SSH vào từng máy, gõ lệnh tay | 1 playbook, chạy trên tất cả |
| Cấu hình sai | Máy này có, máy kia thiếu | **Idempotent** — chạy bao lần cũng ra kết quả giống nhau |
| Audit | Không biết ai đã làm gì | Playbook là document sống |
| Scale | 3 máy làm tay được, 30 máy thì không | Chạy song song, không giới hạn |

## Kiến trúc Ansible

```
┌──────────────┐     SSH      ┌──────────────────────────────┐
│  Control     │──────────────│  Managed Nodes (inventory)    │
│  Node        │              │                              │
│  (máy local) │              │  ├── vm-1  (monitoring)      │
│              │              │  ├── vm-2  (web server)      │
│  playbook.yml│              │  └── vm-3  (database)        │
│  inventory   │              │                              │
│  roles/      │              └──────────────────────────────┘
└──────────────┘
```

## Các khái niệm chính

### 1. Inventory

Danh sách máy đích, chia nhóm:

```ini
# inventory/hosts.ini
[monitoring]
monitoring-vm ansible_host=10.20.1.100 ansible_user=ubuntu

[k8s_nodes]
node-1 ansible_host=10.20.10.26
node-2 ansible_host=10.20.10.94
node-3 ansible_host=10.20.10.29

[all:vars]
ansible_ssh_private_key_file=~/.ssh/techshop-key.pem
ansible_python_interpreter=/usr/bin/python3
```

### 2. Playbook

File YAML định nghĩa **làm gì** trên **máy nào**:

```yaml
# playbooks/install-monitoring.yml
- name: Cài Prometheus + Grafana stack
  hosts: monitoring
  become: yes
  roles:
    - prometheus
    - grafana
    - loki
```

### 3. Role

Đóng gói tasks, templates, variables thành 1 đơn vị tái sử dụng:

```
roles/
└── prometheus/
    ├── tasks/main.yml        # Các bước cài đặt
    ├── templates/prometheus.yml.j2  # Config template
    ├── vars/main.yml         # Biến mặc định
    └── handlers/main.yml     # Restart service khi config thay đổi
```

### 4. Vault

Mã hóa dữ liệu nhạy cảm (password, API key, token):

```bash
# Tạo file mã hóa
ansible-vault create group_vars/monitoring/vault.yml
# → Nhập password, rồi nhập secrets:
#   grafana_admin_password: "supersecret"
#   prometheus_remote_token: "abc123..."

# Chạy playbook với vault password
ansible-playbook playbooks/install-monitoring.yml --ask-vault-pass
```

## Day 3: Sẽ làm gì?

```
┌─────────────────────────────────────────────────┐
│  Dùng Ansible cài monitoring stack lên 1 VM     │
│                                                 │
│  Target: 1 EC2 t3.small (monitoring-vm)         │
│  Tools: Prometheus + Grafana + Loki             │
│                                                 │
│  ansible/                                       │
│  ├── inventory/hosts.ini                        │
│  ├── playbooks/install-monitoring.yml           │
│  └── roles/                                     │
│      ├── prometheus/                            │
│      ├── grafana/                               │
│      └── loki/                                  │
└─────────────────────────────────────────────────┘
```

## Commands ghi nhớ

```bash
# Test kết nối tới inventory
ansible all -i inventory/hosts.ini -m ping

# Chạy 1 lệnh ad-hoc
ansible monitoring -i inventory/hosts.ini -m shell -a "uptime"

# Chạy playbook
ansible-playbook -i inventory/hosts.ini playbooks/install-monitoring.yml

# Check mode (dry-run)
ansible-playbook -i inventory/hosts.ini playbooks/install-monitoring.yml --check

# Xem docs 1 module
ansible-doc apt
ansible-doc copy
ansible-doc systemd
```
