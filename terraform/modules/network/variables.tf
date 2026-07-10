variable "project_name" {
  type    = string
  default = "techshop"

}
variable "region" {
  type    = string
  default = "ap-southeast-1"

}
variable "az_a" {
  type    = string
  default = "ap-southeast-1a"

}
variable "az_b" {
  type    = string
  default = "ap-southeast-1b"

}
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"

}
variable "public_subnet_a_cidr" {
  type    = string
  default = "10.20.1.0/24"

}
variable "private_subnet_a_cidr" {
  type    = string
  default = "10.20.10.0/24"

}
variable "public_subnet_b_cidr" {
  type    = string
  default = "10.20.2.0/24"

}
variable "private_subnet_b_cidr" {
  type    = string
  default = "10.20.20.0/24"

}
