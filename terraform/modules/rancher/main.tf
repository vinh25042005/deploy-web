# Module: rancher — EC2 riêng chạy Rancher Server (Docker)
# Rancher nằm NGOÀI cụm K8s, quản lý cụm từ xa qua kubeconfig

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ── EC2 Instance cho Rancher ──
resource "aws_instance" "rancher" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.rancher_subnet_id
  vpc_security_group_ids = [aws_security_group.rancher.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-rancher" }

  # ── User data: cài Docker + Rancher ──
  user_data = base64encode(templatefile("${path.module}/rancher-init.sh", {
    rancher_version   = var.rancher_version
    bootstrap_password = var.rancher_bootstrap_password
  }))
}

# ── Security Group cho Rancher ──
resource "aws_security_group" "rancher" {
  name        = "${var.project_name}-rancher-sg"
  description = "Allow Rancher web UI + SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "Rancher HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Rancher HTTP (redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = { Name = "${var.project_name}-rancher-sg" }
}
