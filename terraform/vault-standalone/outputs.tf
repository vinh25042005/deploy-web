output "vault_url" {
  value       = "https://${aws_eip.vault.public_ip}:${var.vault_port}"
  description = "Vault URL (dùng cho VAULT_ADDR của Jenkins / backup / injector)"
}

output "vault_ip" {
  value       = aws_eip.vault.public_ip
  description = "Vault Elastic IP (tĩnh)"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/techshop-key.pem ubuntu@${aws_eip.vault.public_ip}"
  description = "SSH command"
}

output "vault_ca_cert" {
  value = "/etc/vault/tls/ca.crt (trên VM) — copy cho Jenkins/backup/injector để trust TLS self-signed"
}
