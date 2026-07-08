# ─── VPC ─────────────────────────────────
output "vpc_name" {
  value       = google_compute_network.main.name
  description = "Tên VPC"
}

output "subnet_a_cidr" {
  value       = google_compute_subnetwork.subnet_a.ip_cidr_range
  description = "CIDR subnet A"
}

# ─── GKE ─────────────────────────────────
output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster name"
}

output "gke_node_count" {
  value       = google_container_node_pool.primary.node_count
  description = "Number of GKE nodes"
}

# ─── Rancher ─────────────────────────────
output "rancher_ip" {
  value       = google_compute_address.rancher.address
  description = "Rancher UI public IP"
}