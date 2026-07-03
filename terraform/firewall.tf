
# Database: chỉ cho backend kết nối
resource "google_compute_firewall" "db" {
  name    = "allow-postgres"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_tags = ["shop-backend"]
  target_tags = ["shop-db"]
}

# Backend API
resource "google_compute_firewall" "backend" {
  name    = "allow-backend"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["shop-backend"]
}

# Frontend
resource "google_compute_firewall" "frontend" {
  name    = "allow-frontend"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["shop-frontend"]
}

# IAP SSH Tunnel (thay thế mở port 22 ra internet)
# Chỉ dải IP của Google IAP được phép SSH vào VM
resource "google_compute_firewall" "allow-iap-ssh" {
  name    = "allow-iap-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["shop"]
}