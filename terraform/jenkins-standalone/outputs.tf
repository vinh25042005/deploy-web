output "jenkins_url" {
  value       = "http://${aws_instance.jenkins.public_ip}:${var.jenkins_port}"
  description = "Jenkins URL"
}

output "jenkins_ip" {
  value       = aws_instance.jenkins.public_ip
  description = "Jenkins public IP"
}

output "ssh_command" {
  value       = "ssh -i <path-to-key> ubuntu@${aws_instance.jenkins.public_ip}"
  description = "SSH command"
}

output "instance_id" {
  value       = aws_instance.jenkins.id
  description = "EC2 instance ID (dùng để stop/start trên AWS Console)"
}
