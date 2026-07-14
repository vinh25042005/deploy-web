terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # S3 bucket + DynamoDB tạo 1 lần thủ công bằng AWS CLI
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
      instance_type = "t3.small"
      key_name      = "techshop-key"
    }
    stg = {
      instance_type = "t3.medium"
      key_name      = "techshop-key"
    }
  }
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
  subnet_ids   = [module.network.public_subnet_a_id, module.network.private_subnet_a_id, module.network.private_subnet_b_id]
  sg_ids        = [module.network.sg_allow_internal_id, module.network.sg_allow_https_id]
  instance_type = local.config[local.env].instance_type
  node_count    = 3
  key_name      = local.config[local.env].key_name
  # ── Ingress nodes (public subnet) ──
  ingress_subnet_ids = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  ingress_sg_ids     = [module.network.sg_allow_internal_id, module.network.sg_allow_ingress_id]
  ingress_count      = 2
}

# ── Kubernetes + Helm provider ──
# Lấy kubeconfig từ SSM (được node-1 upload khi khởi tạo):
#   aws ssm get-parameter --region ap-southeast-1 --name /k8s/kubeconfig \
#     --query Parameter.Value --output text | base64 -d | gzip -d > ~/.kube/techshop-config
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}
provider "helm" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig_path)
  }
}

# ── LƯU Ý: Sau terraform apply, chạy 3 lệnh sau theo thứ tự ──
#
#   Bước 1: Cài K8s cluster bằng Ansible
#     eval $(ssh-agent -s) && ssh-add ~/.ssh/techshop-key.pem
#     ansible-playbook -i ansible/inventory.ini ansible/playbooks/k8s-cluster.yml
#
#   Bước 2: Lấy kubeconfig từ SSM
#     aws ssm get-parameter --region ap-southeast-1 --name /k8s/kubeconfig \
#       --query Parameter.Value --output text | base64 -d | gzip -d > ~/.kube/techshop-config
#
#   Bước 3: Deploy monitoring + app bằng Helm
#     cd helm/techshop && helm dependency update
#     kubectl create ns techshop --dry-run=client -o yaml | kubectl apply -f -
#     helm upgrade --install techshop-dev . --namespace techshop \
#       --set images.backend=nginx:alpine --set images.frontend=nginx:alpine \
#       --set hpa.enabled=false --wait --timeout 10m
