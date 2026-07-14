variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "allowed_sg_ids" { type = list(string) }

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "shopdb"
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  type      = string
  default   = "password123"
  sensitive = true
}

variable "storage_size" {
  type    = number
  default = 20
}

variable "max_storage_size" {
  type    = number
  default = 100
}
