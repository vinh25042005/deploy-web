# Static IP
resource "google_compute_address" "db" {
  name = "shop-db-ip"
}

resource "google_compute_address" "backend" {
  name = "shop-backend-ip"
}

resource "google_compute_address" "frontend" {
  name = "shop-frontend-ip"
}

# ─── Database VM ───
resource "google_compute_instance" "db" {
  name         = "shop-db"
  machine_type = var.db_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = var.vm_disk_size
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.db.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io docker-compose
    systemctl enable docker
    docker run -d --name postgres \
      --restart always \
      -e POSTGRES_USER=${var.db_user} \
      -e POSTGRES_PASSWORD=${var.db_password} \
      -e POSTGRES_DB=${var.db_name} \
      -p 5432:5432 \
      -v /data/postgres:/var/lib/postgresql/data \
      postgres:16-alpine
  EOF

  tags = ["shop-db", "shop"]
}

# ─── Backend VM ───
resource "google_compute_instance" "backend" {
  name         = "shop-backend"
  machine_type = var.backend_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = var.vm_disk_size
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.backend.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
  EOF

  tags = ["shop-backend", "shop"]
}

# ─── Frontend VM ───
resource "google_compute_instance" "frontend" {
  name         = "shop-frontend"
  machine_type = var.frontend_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = var.vm_disk_size
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.frontend.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
  EOF

  tags = ["shop-frontend", "shop"]
}