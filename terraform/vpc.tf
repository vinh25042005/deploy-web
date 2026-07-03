# ─── Custom VPC (chuẩn doanh nghiệp) ───

# VPC
resource "google_compute_network" "main" {
  name                    = "techshop-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet 1 — Asia Southeast1-a (primary, chứa tất cả VM)
resource "google_compute_subnetwork" "subnet_a" {
  name          = "techshop-subnet-a"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = var.subnet_a_cidr
}

# Subnet 2 — Asia Southeast1-b (HA, dự phòng cho tương lai)
resource "google_compute_subnetwork" "subnet_b" {
  name          = "techshop-subnet-b"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = var.subnet_b_cidr
}

# Cloud Router — cần cho Cloud NAT
resource "google_compute_router" "main" {
  name    = "techshop-router"
  network = google_compute_network.main.id
  region  = var.region
}

# Cloud NAT — cho phép VM không có external IP truy cập internet (pull docker image...)
resource "google_compute_router_nat" "main" {
  name                               = "techshop-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
