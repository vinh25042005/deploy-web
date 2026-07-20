output "node_private_ips" { value = aws_instance.node[*].private_ip }
output "node_instance_ids" { value = aws_instance.node[*].id }
output "ingress_public_ips" { value = aws_instance.ingress[*].public_ip }
output "ingress_private_ips" { value = aws_instance.ingress[*].private_ip }
output "ingress_instance_ids" { value = aws_instance.ingress[*].id }
