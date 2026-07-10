output "k8s_node_ips" {
  description = "K8s node private IPs"
  value       = module.compute.node_private_ips
}

output "k8s_node_ids" {
  description = "K8s node instance IDs"
  value       = module.compute.node_instance_ids
}

output "lb_public_ips" {
  description = "Load balancer public IPs"
  value       = module.loadbalancer.lb_public_ips
}

output "rancher_url" {
  description = "Rancher UI URL"
  value       = module.rancher[*].rancher_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "k8s_app_release_name" {
  description = "Helm release name"
  value       = module.k8s_app.release_name
}

output "k8s_app_endpoint" {
  description = "TechShop service endpoint"
  value       = module.k8s_app.service_endpoint
}
