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
  description = "GCP zone"
  type        = string
  default     = "asia-southeast1-a"
}

variable "vm_disk_size" {
  description = "Boot disk size GB"
  type        = number
  default     = 10
}

variable "ssh_user" {
  description = "SSH username for VM"
  type        = string
  default     = "deploy"
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