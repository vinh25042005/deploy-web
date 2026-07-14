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
  description = "Docker image cho backend (không dùng khi chỉ deploy monitoring)"
  default     = "nginx:alpine"
}

variable "frontend_image" {
  type        = string
  description = "Docker image cho frontend (không dùng khi chỉ deploy monitoring)"
  default     = "nginx:alpine"
}

variable "replicas" {
  type        = number
  description = "Số replicas cho backend + frontend"
  default     = 0
}

variable "ingress_host" {
  type        = string
  description = "Ingress hostname"
  default     = "dev.techshop.local"
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
