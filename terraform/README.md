# 🏗️ Terraform — TechShop Infrastructure

Cơ sở hạ tầng GCP cho ứng dụng e-commerce TechShop.

## Kiến trúc

```
VPC: techshop-vpc (10.20.0.0/16)
├── subnet-a: 10.20.1.0/24 (asia-southeast1-a)
├── subnet-b: 10.20.2.0/24 (asia-southeast1-b) — HA dự phòng
├── Cloud Router + Cloud NAT
│
├── shop-db      (e2-small)  — PostgreSQL 16
├── shop-backend (e2-small)  — Express + Prisma
├── shop-frontend(e2-micro)  — Next.js
│
├── shop-db-data (20GB persistent disk)
├── Artifact Registry (Docker images)
│
Firewall:
├── allow-internal    — TCP/UDP/ICMP nội bộ VPC
├── allow-postgres    — 5432 (chỉ từ backend)
├── allow-backend     — 3001 (public)
├── allow-frontend    — 3000 (public)
├── allow-iap-ssh     — 22 (chỉ từ Google IAP)
└── allow-health-check— 3000-3001 (từ GCP health check)
```

## Sử dụng

```bash
# Lần đầu
cp terraform.tfvars.example terraform.tfvars
# Sửa db_password, db_user...

terraform init
terraform plan
terraform apply

# Lấy output
terraform output
```

## Remote State

State lưu trên **GCS bucket** `tfstate-techshop-xxxxx`:
- Object versioning: khôi phục state cũ nếu lỗi
- Built-in locking: tránh conflict khi team cùng apply
- Encrypted at rest

## File structure

```
terraform/
├── versions.tf              # Terraform + provider versions
├── backend.tf               # GCS remote state
├── variables.tf             # Tất cả biến
├── vpc.tf                   # VPC, subnet, router, NAT
├── firewall.tf              # Firewall rules
├── vm.tf                    # Compute instances
├── artifact-registry.tf     # Docker registry
├── outputs.tf               # Output values
├── terraform.tfvars         # Giá trị thật (gitignored)
└── terraform.tfvars.example # Template
```
