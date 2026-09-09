variable "project_name" {
  type    = string
  default = "techshop"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

variable "key_name" {
  type        = string
  default     = "techshop-key"
  description = "AWS EC2 key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.large"
  description = "EC2 instance type cho K8s control-plane nodes"
}

variable "ingress_instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type cho ingress nodes (only NGINX runs here)"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "ingress_count" {
  type        = number
  default     = 0
  description = "Số EC2 ingress nodes chuyên dụng. Đặt 0 để BỎ ingress node (tiết kiệm chi phí) — ingress-nginx chạy trên các node worker/master, NLB trỏ thẳng tới node."
}

variable "vault_addr" {
  type        = string
  default     = "https://52.221.18.86:8200"
  description = "Vault standalone address (injector externalVaultAddr + CI/backup VAULT_ADDR)"
}

variable "frontend_port" {
  type        = number
  default     = 3000
  description = "Frontend service port for NLB health check"
}


variable "backup_bucket_name" {
  type        = string
  default     = "techshop-loki-790400775134"
  description = "S3 bucket for database backup storage"
}

variable "rancher_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}
