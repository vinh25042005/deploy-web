output "rancher_public_ip" { value = aws_instance.rancher.public_ip }
output "rancher_url"       { value = "https://${aws_instance.rancher.public_ip}" }
