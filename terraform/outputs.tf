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

output "backend_internal_ip" {
  value       = google_compute_instance.backend.network_interface[0].network_ip
  description = "Backend VM internal IP (chỉ frontend nối được)"
}

output "frontend_ip" {
  value       = google_compute_address.frontend.address
  description = "Frontend VM public IP"
}

output "lb_ip" {
  value       = google_compute_global_address.lb.address
  description = "Load Balancer IP (truy cập qua HTTPS)"
}

output "frontend_url" {
  value       = "https://${google_compute_global_address.lb.address}"
  description = "Frontend URL qua HTTPS Load Balancer (self-signed cert)"
}