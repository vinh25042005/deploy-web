# Module: k8s-app — Deploy monitoring stack lên K8s cluster bằng Helm
resource "helm_release" "app" {
  name             = "${var.project_name}-${var.env}"
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  wait             = false
  timeout          = 300

  set = [
    {
      name  = "backend.replicas"
      value = "0"
      type  = "string"
    },
    {
      name  = "frontend.replicas"
      value = "0"
      type  = "string"
    },
    {
      name  = "postgres.replicas"
      value = "0"
      type  = "string"
    },
    {
      name  = "hpa.enabled"
      value = "false"
      type  = "string"
    },
  ]
}
