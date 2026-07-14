variable "project_name" {
  type    = string
  default = "techshop"
}
variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "key_name" {
  type    = string
  default = "techshop-key"
}

# ── K8s App variables ──
variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/techshop-config"
}

variable "backend_image" {
  type    = string
  default = "ghcr.io/vinh25042005/deploy-web/backend:latest"
}

variable "frontend_image" {
  type    = string
  default = "ghcr.io/vinh25042005/deploy-web/frontend:latest"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "ingress_host" {
  type    = string
  default = "dev.techshop.local"
}
