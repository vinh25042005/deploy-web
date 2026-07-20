variable "project_name" {
  type    = string
  default = "techshop"
}

variable "rancher_version" {
  type        = string
  default     = "2.9.2"
  description = "Rancher version tag (không có prefix v)"
}

variable "rancher_bootstrap_password" {
  type        = string
  default     = "admin"
  description = "Bootstrap password (change from 'admin' in production)"
  sensitive   = true
}

variable "rancher_subnet_id" {
  type        = string
  description = "Public subnet ID cho Rancher EC2"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type cho Rancher (cần >= 4GB RAM)"
}

variable "disk_size" {
  type        = number
  default     = 30
  description = "Root disk size (GB)"
}

