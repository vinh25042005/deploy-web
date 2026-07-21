variable "project_name" {
  type    = string
  default = "techshop"
}

variable "jenkins_subnet_id" {
  type        = string
  description = "Public subnet ID cho Jenkins EC2"
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
  default     = "t3.small"
  description = "EC2 instance type cho Jenkins (t3.small = 2GB RAM, đủ chạy Jenkins + Docker)"
}

variable "disk_size" {
  type        = number
  default     = 10
  description = "Root volume size (GB)"
}

variable "jenkins_port" {
  type        = number
  default     = 9090
  description = "Jenkins web UI port"
}
