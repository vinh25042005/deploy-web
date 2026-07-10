# Module: Network (AWS) — 2 AZ × 2 tầng public/private
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name
}-vpc" }
}

# PUBLIC SUBNETS
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_a_cidr
  availability_zone = var.az_a
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name
}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = var.az_b
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name
}-public-b" }
}

# PRIVATE SUBNETS
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = var.az_a
  tags = { Name = "${var.project_name
}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = var.az_b
  tags = { Name = "${var.project_name
}-private-b" }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name
}-igw" }
}

# Elastic IP cho NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

}

# NAT Gateway (đặt trong public subnet A)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "${var.project_name
}-nat" }
}

# Route table PUBLIC → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  
}
  tags = {
  Name = "${var.project_name
}-rt-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id

}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id

}

# Route table PRIVATE → NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  
}
  tags = {
  Name = "${var.project_name
}-rt-private" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id

}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id

}

# SECURITY GROUPS
resource "aws_security_group" "allow_internal" {
  name        = "${var.project_name
}-allow-internal"
  description = "Allow all VPC internal traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
  from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.public_subnet_a_cidr, var.public_subnet_b_cidr, var.private_subnet_a_cidr, var.private_subnet_b_cidr]
  
}
  egress {
  from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  
}
}

resource "aws_security_group" "allow_https" {
  name        = "${var.project_name
}-allow-https"
  description = "Allow HTTPS + K8s API from internet"
  vpc_id      = aws_vpc.main.id
  ingress {
  from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  ingress {
  from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  ingress {
  from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  ingress {
  from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  ingress {
  from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  egress {
  from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  
}
}
