variable "project_name" {
  type    = string
  default = "techshop"
}
variable "subnet_id" {
  type = string
}
variable "sg_ids" {
  type = list(string)
}
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "key_name" {
  type    = string
  default = ""
}
variable "rancher_version" {
  type    = string
  default = "v2.14.3"
}
variable "disk_size" {
  type    = number
  default = 30
}
