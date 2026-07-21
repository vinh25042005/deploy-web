terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "techshop-tfstate"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "techshop-tfstate-lock"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# ── Locals ──
locals {
  env = terraform.workspace
}

# ── Network ──
module "network" {
  source       = "../modules/network"
  project_name = var.project_name
  region       = var.region
}

# ── Compute: K8s nodes (private subnet, SSM) ──
module "compute" {
  source        = "../modules/compute"
  project_name  = var.project_name
  region        = var.region
  subnet_ids    = [module.network.public_subnet_a_id, module.network.private_subnet_a_id, module.network.private_subnet_b_id]
  sg_ids        = [module.network.sg_allow_internal_id, module.network.sg_allow_https_id]
  instance_type = var.instance_type
  node_count    = var.node_count
  key_name      = var.key_name
  # ── Ingress nodes (public subnet) ──
  ingress_subnet_ids = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  ingress_sg_ids     = [module.network.sg_allow_internal_id, module.network.sg_allow_ingress_id]
  ingress_count      = var.ingress_count
  backup_bucket_name = var.backup_bucket_name
}

# ── Kubernetes + Helm provider ──
# Lấy kubeconfig từ SSM (được node-1 upload khi khởi tạo):
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}
provider "helm" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig_path)
  }
}

# ── NLB cho Ingress: Terraform quản lý thay vì Helm ──
resource "aws_lb" "ingress" {
  name               = "${var.project_name}-ingress-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]

  # Giữ NLB khi destroy Helm (tránh bị xóa rồi tạo lại)
  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-ingress-nlb" }
}

resource "aws_lb_target_group" "ingress_http" {
  name     = "${var.project_name}-ingress-http"
  port     = 80
  protocol = "TCP"
  vpc_id   = module.network.vpc_id

  health_check {
    port     = "80"
    protocol = "HTTP"
    path     = "/healthz"
    matcher  = "200-399"
  }

  tags = { Name = "${var.project_name}-ingress-http" }
}

resource "aws_lb_target_group" "ingress_https" {
  name     = "${var.project_name}-ingress-https"
  port     = 443
  protocol = "TCP"
  vpc_id   = module.network.vpc_id

  health_check {
    port     = "80"
    protocol = "HTTP"
    path     = "/healthz"
    matcher  = "200-399"
  }

  tags = { Name = "${var.project_name}-ingress-https" }
}

# Gắn ingress nodes vào target group (dùng instance ID)
resource "aws_lb_target_group_attachment" "ingress_http" {
  count            = 2
  target_group_arn = aws_lb_target_group.ingress_http.arn
  target_id        = module.compute.ingress_instance_ids[count.index]
  port             = 80
}

resource "aws_lb_target_group_attachment" "ingress_https" {
  count            = 2
  target_group_arn = aws_lb_target_group.ingress_https.arn
  target_id        = module.compute.ingress_instance_ids[count.index]
  port             = 443
}

resource "aws_lb_listener" "ingress_http" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_http.arn
  }
}

resource "aws_lb_listener" "ingress_https" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_https.arn
  }
}

# ── Rancher: EC2 riêng, nằm NGOÀI cụm K8s ──
module "rancher" {
  source = "../modules/rancher"

  project_name      = var.project_name
  rancher_subnet_id = module.network.public_subnet_a_id
  vpc_id            = module.network.vpc_id
  key_name          = var.key_name
  instance_type     = var.rancher_instance_type
}

# ── Ansible: tự động cài K8s cluster sau khi tất cả resource (kể cả NLB) ready ──
resource "null_resource" "ansible" {
  depends_on = [
    module.compute,
    module.rancher,
    module.network,
    aws_lb.ingress,
    aws_lb_listener.ingress_http,
    aws_lb_listener.ingress_https,
    aws_lb_target_group_attachment.ingress_http,
    aws_lb_target_group_attachment.ingress_https,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo ">>> Terraform outputs:"
      terraform output
      echo ""
      echo ">>> Waiting 30s for nodes to boot..."
      sleep 30
      echo ">>> Starting SSH agent and running Ansible..."
      ssh-agent -s > /tmp/ssh-agent.sh
      . /tmp/ssh-agent.sh
      ssh-add ~/.ssh/techshop-key.pem 2>/dev/null || true
      # Download kubeconfig
      aws ssm get-parameter --name /k8s/kubeconfig --region ap-southeast-1 \
        --with-decryption --query 'Parameter.Value' --output text | base64 -d > /tmp/kcfg.gz
      gzip -d -f /tmp/kcfg.gz 2>/dev/null && cp /tmp/kcfg ~/.kube/techshop-config 2>/dev/null || true
      mkdir -p ~/.kube
      cp /tmp/kcfg ~/.kube/techshop-config 2>/dev/null || true
      cd ${path.root}/../../ansible
      ansible-playbook -i inventory.ini playbooks/k8s-cluster.yml \
        --ssh-common-args="-o StrictHostKeyChecking=accept-new"
    EOT
  }
}
