variable "project_name" {
  type    = string
  default = "techshop"
}
variable "subnet_ids" {
  type = list(string)
}
variable "sg_ids" {
  type = list(string)
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "key_name" {
  type    = string
  default = ""
}
variable "node_ips" {
  type    = list(string)
  default = []
}
