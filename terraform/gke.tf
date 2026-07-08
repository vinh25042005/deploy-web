# GKE Standard Cluster 

resource "google_container_cluster" "primary" {
  name     = "techshop-gke"
  location = var.zone

  network    = google_compute_network.main.self_link
  subnetwork = google_compute_subnetwork.subnet_a.self_link

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {}

  deletion_protection = false
}

resource "google_container_node_pool" "primary" {
  name     = "techshop-node-pool"
  cluster  = google_container_cluster.primary.name
  location = var.zone

  node_count = 3

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}