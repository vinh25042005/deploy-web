
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

resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["shop"]
}