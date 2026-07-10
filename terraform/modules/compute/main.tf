# Module: Compute (AWS) — 3 EC2 master kiêm worker + kubeadm
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ── IAM Role cho SSM Session Manager (không cần public IP) ──
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_ssm" {
  name               = "${var.project_name}-node-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline policy cho phép đọc/ghi SSM Parameter Store (auto-join K8s)
resource "aws_iam_role_policy" "node_ssm_params" {
  name = "${var.project_name}-ssm-params"
  role = aws_iam_role.node_ssm.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter", "ssm:GetParameter", "ssm:GetParametersByPath", "ssm:DeleteParameter"]
        Resource = "arn:aws:ssm:${var.region}:*:parameter/k8s/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node_ssm" {
  name = "${var.project_name}-node-ssm-profile"
  role = aws_iam_role.node_ssm.name
}

# 3 EC2 node - private subnet, NAT cho internet, SSM để SSH
resource "aws_instance" "node" {
  count                  = var.node_count
  ami                    = data.aws_ami.ubuntu.id
  iam_instance_profile   = aws_iam_instance_profile.node_ssm.name
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.sg_ids
  key_name               = var.key_name

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/scripts/install-k8s-aws.sh", {
    node_type   = count.index == 0 ? "master-first" : "master-join"
    pod_cidr    = var.pod_network_cidr
    k8s_version = var.kubernetes_version
  }))

  tags = { Name = "${var.project_name}-k8s-node-${count.index + 1}" }
}
  
