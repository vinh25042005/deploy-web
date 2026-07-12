# File: terraform/outputs.tf

output "public_ip" {
  description = "Public IP của monitoring VM"
  value       = aws_instance.monitoring.public_ip
}

output "ssh_command" {
  description = "Lệnh SSH vào VM"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.monitoring.public_ip}"
}
