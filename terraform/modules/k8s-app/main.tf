# Module: k8s-app — Deploy TechShop app lên K8s cluster bằng Helm
resource "helm_release" "app" {
  name             = "${var.project_name}-${var.env}"
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  set = [
    {
      name  = "images.backend"
      value = var.backend_image
      type  = "string"
    },
    {
      name  = "images.frontend"
      value = var.frontend_image
      type  = "string"
    },
    {
      name  = "backend.replicas"
      value = var.replicas
      type  = "string"
    },
    {
      name  = "frontend.replicas"
      value = var.replicas
      type  = "string"
    },
    {
      name  = "ingress.host"
      value = var.ingress_host
      type  = "string"
    },
  ]
}
