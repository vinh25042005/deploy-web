variable "project_name" {
  type        = string
  default     = "techshop"
  description = "Project name (dùng để đặt tên resource)"
}

variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region"
}

variable "key_name" {
  type        = string
  default     = "techshop-key"
  description = "SSH key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type cho Vault (Vault rất nhẹ — t3.small 2GB là dư sức)"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "Root volume size (GB) — data Vault nằm trên EBS này"
}

variable "vault_version" {
  type        = string
  default     = "1.18.5"
  description = "Vault binary version"
}

variable "vault_port" {
  type        = number
  default     = 8200
  description = "Vault HTTPS port"
}

# ── KMS key dùng cho seal (auto-unseal). Giữ nguyên key đang dùng cho Vault in-cluster cũ ──
variable "kms_key_id" {
  type        = string
  default     = "5f9e342a-d45d-4a93-9841-0398fe67b7da"
  description = "AWS KMS key ID cho seal 'awskms'"
}

# ── CIDR được phép gọi Vault:8200 ──
#   Enterprise: chỉ cho IP egress của k8s nodes + Jenkins + ops. Do TLS đã bật,
#   lab có thể để 0.0.0.0/0 rồi thu hẹp sau. Điền CIDR thật vào đây khi chạy thật.
variable "vault_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR được phép truy cập Vault port 8200 (nên thu hẹp theo IP thật)"
}

# ── Hostname clients sẽ dùng để gọi Vault (SAN trong cert) ──
variable "vault_hostname" {
  type        = string
  default     = "vault.techshop.local"
  description = "Hostname trong cert self-signed + API_ADDR (clients phải resolve được về EIP)"
}
