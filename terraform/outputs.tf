# ─── VPC ─────────────────────────────────
output "vpc_name" {
  value       = google_compute_network.main.name
  description = "Tên VPC"
}

output "vpc_self_link" {
  value       = google_compute_network.main.self_link
  description = "VPC self link"
}

output "subnet_a_cidr" {
  value       = google_compute_subnetwork.subnet_a.ip_cidr_range
  description = "CIDR subnet A"
}

# ─── VM IPs ──────────────────────────────
output "db_ip" {
  value       = google_compute_address.db.address
  description = "Database VM public IP"
}

output "backend_ip" {
  value       = google_compute_address.backend.address
  description = "Backend VM public IP"
}

output "frontend_ip" {
  value       = google_compute_address.frontend.address
  description = "Frontend VM public IP"
}

output "frontend_url" {
  value       = "http://${google_compute_address.frontend.address}:3000"
  description = "Frontend URL"
}

output "backend_url" {
  value       = "http://${google_compute_address.backend.address}:3001"
  description = "Backend API URL"
}