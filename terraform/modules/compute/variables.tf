variable "project_name" {
  type    = string
  default = "techshop"

}
variable "region" {
  type    = string
  default = "ap-southeast-1"

}
variable "az" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}
variable "subnet_ids" {
  type = list(string)
}
variable "sg_ids"         {
  type = list(string) 
}
variable "key_name" {
  type    = string
  default = ""

}
variable "instance_type" {
  type    = string
  default = "t3.small"

}
variable "node_count" {
  type    = number
  default = 3

}
variable "disk_size" {
  type    = number
  default = 20

}
variable "pod_network_cidr" {
  type    = string
  default = "10.244.0.0/16"

}
variable "kubernetes_version" {
  type    = string
  default = "1.35"

}
