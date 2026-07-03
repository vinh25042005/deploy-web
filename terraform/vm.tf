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

# ─── Persistent Disk cho PostgreSQL data ───
# Tồn tại độc lập với VM, không bị xóa khi rebuild VM
resource "google_compute_disk" "db_data" {
  name = "shop-db-data"
  size = var.db_data_disk_size
  zone = var.zone
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

  # Gắn persistent disk riêng cho data PostgreSQL
  attached_disk {
    source      = google_compute_disk.db_data.id
    device_name = "db-data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_a.self_link
    access_config {
      nat_ip = google_compute_address.db.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io docker-compose
    systemctl enable docker

    # Mount persistent data disk
    DATA_DISK=/dev/disk/by-id/google-db-data
    if ! blkid $DATA_DISK 2>/dev/null; then
      mkfs.ext4 -F $DATA_DISK
    fi
    mkdir -p /data
    mount $DATA_DISK /data
    echo "$DATA_DISK /data ext4 defaults 0 0" >> /etc/fstab

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
    subnetwork = google_compute_subnetwork.subnet_a.self_link
    access_config {
      nat_ip = google_compute_address.backend.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker deploy
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
    subnetwork = google_compute_subnetwork.subnet_a.self_link
    access_config {
      nat_ip = google_compute_address.frontend.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker deploy
  EOF

  tags = ["shop-frontend", "shop"]
}