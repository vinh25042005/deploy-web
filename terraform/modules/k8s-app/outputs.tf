output "release_name" {
  description = "Helm release name"
  value       = helm_release.app.name
}

output "service_endpoint" {
  description = "Service endpoint (ingress URL)"
  value       = "https://${var.ingress_host}"
}

output "namespace" {
  description = "K8s namespace đã deploy"
  value       = helm_release.app.namespace
}
