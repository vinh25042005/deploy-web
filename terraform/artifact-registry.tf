# ─── Artifact Registry ───
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "techshop"
  format        = "DOCKER"
}