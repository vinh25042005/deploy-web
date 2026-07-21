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
  type    = string
  default = "t3.medium"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "ingress_count" {
  type    = number
  default = 2
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

variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
  description = "EC2 type for Jenkins"
}

variable "jenkins_disk_size" {
  type    = number
  default = 10
  description = "Jenkins root volume size (GB)"
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}
