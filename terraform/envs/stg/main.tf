terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket  = "techshop-tfstate-stg"
    key     = "terraform.tfstate"
    region  = "ap-southeast-1"
    encrypt = true
  }
}

provider "aws" {
  region  = var.region
  profile = "default"
}

module "state_backend" {
  source       = "../../modules/state-backend"
  project_name = var.project_name
  env          = "stg"
}

module "network" {
  source       = "../../modules/network"
  project_name = var.project_name
  region       = var.region
}

module "compute" {
  source        = "../../modules/compute"
  project_name  = var.project_name
  region        = var.region
  subnet_ids   = [module.network.private_subnet_a_id, module.network.private_subnet_b_id]
  sg_ids        = [module.network.sg_allow_internal_id, module.network.sg_allow_https_id]
  instance_type = "t3.medium"
  node_count    = 3
}

module "loadbalancer" {
  source        = "../../modules/loadbalancer"
  project_name  = var.project_name
  subnet_ids   = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  sg_ids        = [module.network.sg_allow_https_id]
  instance_type = "t3.micro"
}

# ── Kubernetes + Helm provider ──
provider "kubernetes" {
  config_path = var.kubeconfig_path
}
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# ── K8s App (Helm deploy TechShop lên cluster) ──
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

module "k8s_app" {
  source         = "../../modules/k8s-app"
  project_name   = var.project_name
  env            = "stg"
  backend_image  = var.backend_image
  frontend_image = var.frontend_image
  replicas       = var.replicas
  ingress_host   = var.ingress_host
  chart_path     = abspath("${path.module}/../../helm/techshop")
  depends_on     = [terraform_data.fetch_kubeconfig]
}

