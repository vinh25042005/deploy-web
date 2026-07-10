terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Step 1: init với local, apply tạo bucket
  # Step 2: đổi sang S3 + migrate state
  backend "s3" {
    bucket  = "techshop-tfstate"
    key     = "terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}

provider "aws" {
  region  = var.region
  profile = "default"
}

# ── Locals: tự động chọn config theo workspace ──
locals {
  env = terraform.workspace

  # Map config cho từng môi trường
  config = {
    dev = {
      instance_type   = "t3.small"
      key_name        = "techshop-key"
      backend_image   = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/backend:latest"
      frontend_image  = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/frontend:latest"
      replicas        = 2
      ingress_host    = "dev.techshop.local"
    }
    stg = {
      instance_type   = "t3.medium"
      key_name        = "techshop-key"
      backend_image   = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/backend:latest"
      frontend_image  = "asia-southeast1-docker.pkg.dev/techshop-prod-2026/techshop/frontend:latest"
      replicas        = 2
      ingress_host    = "stg.techshop.local"
    }
  }
}

# ── S3 + DynamoDB cho tfstate ──
module "state_backend" {
  source       = "../modules/state-backend"
  project_name = var.project_name
  env          = local.env
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
  subnet_ids   = [module.network.private_subnet_a_id, module.network.private_subnet_a_id, module.network.private_subnet_b_id]
  sg_ids        = [module.network.sg_allow_internal_id, module.network.sg_allow_https_id]
  instance_type = local.config[local.env].instance_type
  node_count    = 3
  key_name      = local.config[local.env].key_name
}

# ── Kubernetes + Helm provider ──
# Lấy kubeconfig từ SSM (được node-1 upload khi khởi tạo):
#   aws ssm get-parameter --region ap-southeast-1 --name /k8s/kubeconfig \
#     --query Parameter.Value --output text | base64 -d | gzip -d > ~/.kube/techshop-config
provider "kubernetes" {
  config_path = var.kubeconfig_path
}
provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

# ── Fetch kubeconfig từ SSM (node-1 upload sau khi init cluster) ──
resource "terraform_data" "fetch_kubeconfig" {
  depends_on = [module.compute]

  provisioner "local-exec" {
    command = <<-EOT
      echo ">>> Đợi kubeconfig từ SSM..."
      for i in $(seq 1 12); do
        VALUE=$(aws ssm get-parameter --region ${var.region} \
          --name /k8s/kubeconfig --query Parameter.Value --output text 2>/dev/null)
        if [ -n "$VALUE" ] && [ "$VALUE" != "None" ]; then
          echo "$VALUE" | base64 -d | gzip -d > ${var.kubeconfig_path} 2>/dev/null && break
        fi
        echo ">>> Đợi... ($i/12)"
        sleep 10
      done
      echo ">>> Kubeconfig đã lưu tại: ${var.kubeconfig_path}"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# ── K8s App (Helm deploy TechShop lên cluster) ──
module "k8s_app" {
  source         = "../modules/k8s-app"
  project_name   = var.project_name
  env            = local.env
  backend_image  = local.config[local.env].backend_image
  frontend_image = local.config[local.env].frontend_image
  replicas       = local.config[local.env].replicas
  ingress_host   = local.config[local.env].ingress_host
  chart_path     = abspath("${path.module}/../../helm/techshop")
  depends_on     = [terraform_data.fetch_kubeconfig]
}
