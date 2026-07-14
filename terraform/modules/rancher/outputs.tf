output "rancher_public_ip" {
  description = "Rancher server public IP"
  value       = aws_instance.rancher.public_ip
}

output "rancher_url" {
  description = "Rancher URL"
  value       = "https://${aws_instance.rancher.public_ip}"
}

output "rancher_bootstrap" {
  description = "Bootstrap credentials"
  value       = "admin / ${var.rancher_bootstrap_password}"
  sensitive   = true
}

