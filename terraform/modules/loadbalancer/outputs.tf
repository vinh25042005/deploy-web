output "lb_public_ips" { value = aws_instance.lb[*].public_ip }
