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
    use_lockfile   = true
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

# ── Ansible: tự động cài K8s cluster sau khi tất cả resource ready ──
resource "null_resource" "ansible" {
  # Re-run Ansible nếu instance bị thay thế (IP đổi → inventory đổi)
  triggers = {
    instance_ids = join(",", concat(
      module.compute.node_instance_ids,
      module.compute.ingress_instance_ids
    ))
  }

  depends_on = [
    module.compute,       # (bao gồm local_file.ansible_inventory)
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
      KEY=~/.ssh/techshop-key.pem
      INVENTORY="${path.root}/../../ansible/inventory.ini"
      NODES=$(grep -oP 'ansible_host=\K[0-9.]+' "$INVENTORY" | grep -v '^10\.' | sort -u)

      echo ">>> Fix key permissions..."
      chmod 600 "$KEY"

      echo ">>> Waiting for all nodes to be SSH-ready..."
      FAILED=0
      for IP in $NODES; do
        echo "  Waiting for $IP:22 ..."
        SUCCESS=0
        for i in $(seq 1 30); do
          if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY" ubuntu@$IP "exit" 2>/dev/null; then
            SUCCESS=1
            break
          fi
          echo "    retry $i/30..."
          sleep 10
        done
        if [ "$SUCCESS" -eq 0 ]; then
          echo "  ERROR: $IP not reachable after 30 retries!"
          FAILED=1
        fi
      done

      if [ "$FAILED" -eq 1 ]; then
        echo ">>> Some nodes not reachable! Aborting."
        exit 1
      fi
      echo ">>> All nodes ready!"

      echo ">>> Starting SSH agent..."
      eval $(ssh-agent -s)
      ssh-add "$KEY"

      echo ">>> Running Ansible (retry up to 3 times, timeout 20m)..."
      cd "$(dirname "$INVENTORY")"
      for i in $(seq 1 3); do
        if timeout 1200 ansible-playbook -i inventory.ini playbooks/k8s-cluster.yml; then
          echo ">>> Ansible completed successfully!"
          exit 0
        fi
        echo "    Ansible attempt $i/3 failed, retrying in 30s..."
        sleep 30
      done
      echo ">>> Ansible failed after 3 attempts"
      exit 1
    EOT
  }
}
