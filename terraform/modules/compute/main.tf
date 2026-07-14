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

# Inline policy: SSM + EBS (cho CSI driver)
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
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:CreateVolume", "ec2:DeleteVolume", "ec2:DescribeVolumes",
          "ec2:AttachVolume", "ec2:DetachVolume", "ec2:DescribeInstances",
          "ec2:CreateTags", "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::techshop-loki-790400775134",
          "arn:aws:s3:::techshop-loki-790400775134/*"
        ]
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

  # K8s cài qua Ansible (không dùng user_data script)
  tags = { Name = "${var.project_name}-k8s-node-${count.index + 1}" }
}

# ── Ingress Nodes: 2 EC2 public subnet, join K8s as worker role=ingress ──
resource "aws_instance" "ingress" {
  count                  = var.ingress_count
  ami                    = data.aws_ami.ubuntu.id
  iam_instance_profile   = aws_iam_instance_profile.node_ssm.name
  instance_type          = var.instance_type
  subnet_id              = var.ingress_subnet_ids[count.index % length(var.ingress_subnet_ids)]
  vpc_security_group_ids = var.ingress_sg_ids
  key_name               = var.key_name

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  # K8s cài qua Ansible (không dùng user_data script)
  tags = { Name = "${var.project_name}-ingress-${count.index + 1}" }
}

# ── Generate Ansible inventory (INI format, reliable) ──
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    master_host = {
      name       = "${var.project_name}-k8s-node-1"
      public_ip  = aws_instance.node[0].public_ip
    }
    worker_hosts = [
      for i in range(1, var.node_count) : {
        name      = "${var.project_name}-k8s-node-${i + 1}"
        private_ip = aws_instance.node[i].private_ip
        bastion   = aws_instance.node[0].public_ip
      }
    ]
    ingress_hosts = [
      for i in range(var.ingress_count) : {
        name      = "${var.project_name}-ingress-${i + 1}"
        public_ip = aws_instance.ingress[i].public_ip
      }
    ]
    key_file = "~/.ssh/${var.key_name}.pem"
  })
  filename = "${path.root}/../../ansible/inventory.ini"
}
  
