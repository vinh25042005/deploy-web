variable "project_name" {
  type    = string
  default = "techshop"
}
variable "region" {
  type    = string
  default = "ap-southeast-1"
}

# ── K8s App variables ──
variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/techshop-config"
}

variable "backend_image" {
  type    = string
  default = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/backend:latest"
}

variable "frontend_image" {
  type    = string
  default = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/frontend:latest"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "ingress_host" {
  type    = string
  default = "stg.techshop.local"
}
