terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ── VPC riêng cho Vault (tách biệt, giống jenkins-standalone) ──
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vault-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-vault-public" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-vault-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-vault-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Group: SSH + Vault:8200 (restricted) ──
resource "aws_security_group" "vault" {
  name        = "${var.project_name}-vault-sg"
  description = "SSH + Vault 8200 (TLS) cho Vault standalone"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Vault HTTPS"
    from_port   = var.vault_port
    to_port     = var.vault_port
    protocol    = "tcp"
    cidr_blocks = var.vault_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-vault-sg" }
}

# ── IAM: Vault cần KMS (seal) + SSM (đọc root/unseal + seed secret) ──
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault" {
  name               = "${var.project_name}-vault-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "vault_ssm_core" {
  role       = aws_iam_role.vault.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "vault_kms_seal" {
  name = "${var.project_name}-vault-kms"
  role = aws_iam_role.vault.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = "arn:aws:kms:${var.region}:*:key/${var.kms_key_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParametersByPath", "ssm:PutParameter"]
        Resource = ["arn:aws:ssm:${var.region}:*:parameter/techshop/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "vault" {
  name = "${var.project_name}-vault-profile"
  role = aws_iam_role.vault.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ── EIP tạo TRƯỚC (để user_data biết IP → sinh cert SAN + api_addr) ──
resource "aws_eip" "vault" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-vault-eip" }
}

resource "aws_instance" "vault" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.vault.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.vault.name

  metadata_options {
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-vault" }

  user_data = templatefile("${path.module}/vault-init.sh", {
    vault_eip      = aws_eip.vault.public_ip
    vault_hostname = var.vault_hostname
    vault_version  = var.vault_version
    vault_port     = var.vault_port
    kms_key_id     = var.kms_key_id
    region         = var.region
  })
}

# Gắn EIP sau khi instance tồn tại
resource "aws_eip_association" "vault" {
  allocation_id = aws_eip.vault.id
  instance_id   = aws_instance.vault.id
}
