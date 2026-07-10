# Outputs Network (AWS)
output "vpc_id"                         { value = aws_vpc.main.id }
output "public_subnet_a_id"             { value = aws_subnet.public_a.id }
output "public_subnet_b_id"             { value = aws_subnet.public_b.id }
output "private_subnet_a_id"            { value = aws_subnet.private_a.id }
output "private_subnet_b_id"            { value = aws_subnet.private_b.id }
output "sg_allow_internal_id"           { value = aws_security_group.allow_internal.id }
output "sg_allow_https_id"              { value = aws_security_group.allow_https.id }
