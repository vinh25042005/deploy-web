output "k8s_node_ips" {
  description = "K8s node private IPs"
  value       = module.compute.node_private_ips
}

output "k8s_node_ids" {
  description = "K8s node instance IDs"
  value       = module.compute.node_instance_ids
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "monitoring_grafana" {
  description = "Grafana URL (port-forward after apply)"
  value       = "kubectl port-forward -n techshop svc/techshop-dev-grafana 9999:80"
}
