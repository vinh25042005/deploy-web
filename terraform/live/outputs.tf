output "ingress_public_ips" {
  description = "Ingress node public IPs"
  value       = module.compute.ingress_public_ips
}

output "ingress_nlb_dns" {
  description = "NLB DNS name for ingress (dùng thay IP trong Helm)"
  value       = aws_lb.ingress.dns_name
}

output "rancher_url" {
  description = "Rancher URL"
  value       = module.rancher.rancher_url
}

output "monitoring_grafana" {
  description = "Grafana URL"
  value       = "kubectl port-forward -n techshop svc/techshop-dev-grafana 9999:80"
}
