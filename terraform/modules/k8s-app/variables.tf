variable "project_name" {
  type        = string
  description = "Tên project (techshop)"
}

variable "env" {
  type        = string
  description = "Môi trường (dev / stg)"
}

variable "backend_image" {
  type        = string
  description = "Docker image cho backend"
}

variable "frontend_image" {
  type        = string
  description = "Docker image cho frontend"
}

variable "replicas" {
  type        = number
  description = "Số replicas cho backend + frontend"
  default     = 2
}

variable "ingress_host" {
  type        = string
  description = "Ingress hostname (VD: dev.techshop.local)"
}

variable "chart_path" {
  type        = string
  description = "Đường dẫn tới Helm chart"
}

variable "namespace" {
  type        = string
  description = "K8s namespace để deploy"
  default     = "techshop"
}
