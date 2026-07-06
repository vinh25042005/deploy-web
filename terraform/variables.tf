variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "techshop-prod-2026"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "GCP zone (primary)"
  type        = string
  default     = "asia-southeast1-a"
}

# ─── VPC Networking ──────────────────────
variable "subnet_a_cidr" {
  description = "CIDR for primary subnet (zone a)"
  type        = string
  default     = "10.20.1.0/24"
}

variable "subnet_b_cidr" {
  description = "CIDR for HA subnet (zone b)"
  type        = string
  default     = "10.20.2.0/24"
}

variable "vm_disk_size" {
  description = "Boot disk size GB"
  type        = number
  default     = 10
}

variable "db_data_disk_size" {
  description = "Persistent disk GB for PostgreSQL data"
  type        = number
  default     = 20
}

variable "monitor_disk_size" {
  description = "Monitoring VM boot disk GB"
  type        = number
  default     = 20
}

variable "ssh_user" {
  description = "SSH username for VM"
  type        = string
  default     = "deploy"
}

# ─── Database credentials  ───
variable "db_user" {
  description = "PostgreSQL user"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "shopdb"
}

# ─── Per-VM machine types ───
variable "db_machine_type" {
  default = "e2-small"    # Postgres
}

variable "backend_machine_type" {
  default = "e2-small"    # Express + Prisma
}

variable "frontend_machine_type" {
  default = "e2-micro"    # Next.js
}
variable "monitor_machine_type" {
  description = "Monitoring VM machine type"
  type        = string
  default     = "e2-small"
}