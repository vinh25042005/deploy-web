output "node_private_ips"  { value = aws_instance.node[*].private_ip }
output "node_instance_ids" { value = aws_instance.node[*].id }
