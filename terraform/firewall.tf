# ─── Firewall Rules (gắn vào VPC riêng) ───

# Cho phép giao tiếp nội bộ giữa các VM trong VPC
resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_a_cidr, var.subnet_b_cidr]
}

# Database: chỉ cho backend VM + GKE pods kết nối
resource "google_compute_firewall" "db" {
  name    = "allow-postgres"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_tags  = ["shop-backend"]
  source_ranges = ["10.88.0.0/14"]
  target_tags  = ["shop-db"]
}

# Backend API: chỉ cho frontend nội bộ (Next.js proxy /api/*)
# Backend không mở port ra Internet → bảo mật hơn
resource "google_compute_firewall" "backend" {
  name    = "allow-backend"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  source_tags = ["shop-frontend"]
  target_tags = ["shop-backend"]
}

# Frontend: chỉ cho Load Balancer + Health Check (không mở 0.0.0.0/0)
resource "google_compute_firewall" "frontend" {
  name    = "allow-frontend"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["shop-frontend"]
}

# IAP SSH Tunnel
resource "google_compute_firewall" "allow-iap-ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["shop"]
}

# Health check từ Google Cloud (Load Balancer, Managed Instance Group...)
resource "google_compute_firewall" "allow-health-check" {
  name    = "allow-health-check"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["3000", "3001"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["shop-backend", "shop-frontend"]
}

# Rancher UI: mở port 80/443 ra Internet
resource "google_compute_firewall" "rancher" {
  name    = "allow-rancher"
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["shop-rancher"]
}