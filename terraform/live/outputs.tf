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
  value       = "kubectl port-forward -n ${var.project_name} svc/${var.project_name}-dev-grafana 9999:80"
}

output "etc_hosts_entry" {
  description = "Add to /etc/hosts: <NLB_IP> project.local grafana.project.local"
  value       = "<dig +short ${aws_lb.ingress.dns_name} | head -1> ${var.project_name}.local grafana.${var.project_name}.local"
}

output "etc_hosts_cmd" {
  description = "Run this to auto-add NLB IP to /etc/hosts"
  value       = "dig +short ${aws_lb.ingress.dns_name} | head -1 | xargs -I{} echo \"{} ${var.project_name}.local grafana.${var.project_name}.local\" | sudo tee -a /etc/hosts"
}
