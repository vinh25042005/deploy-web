variable "project_name" {
  type        = string
  default     = "techshop"
  description = "Project name (dùng để đặt tên resource)"
}

variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region"
}

variable "key_name" {
  type        = string
  default     = "techshop-key"
  description = "SSH key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.large"
  description = "EC2 instance type"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "Root volume size (GB)"
}

variable "jenkins_port" {
  type        = number
  default     = 9090
  description = "Jenkins web UI port"
}
