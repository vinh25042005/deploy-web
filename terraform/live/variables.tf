variable "project_name" {
  type    = string
  default = "techshop"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "az" {
  type    = string
  default = "ap-southeast-1a"
}

# ── K8s App variables ──
variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/techshop-config"
}
