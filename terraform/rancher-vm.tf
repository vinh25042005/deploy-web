# ─── Rancher VM ───

resource "google_compute_address" "rancher" {
  name = "shop-rancher-ip"
}

resource "google_compute_address" "rancher_internal" {
  name         = "shop-rancher-internal"
  address_type = "INTERNAL"
  address      = "10.20.1.10"
  subnetwork   = google_compute_subnetwork.subnet_a.self_link
}

# Persistent disk cho Rancher data
resource "google_compute_disk" "rancher_data" {
  name = "shop-rancher-data"
  size = 30
  type = "pd-standard"
  zone = var.zone
}

resource "google_compute_instance" "rancher" {
  name         = "shop-rancher"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.rancher_data.id
    device_name = "rancher-data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_a.self_link
    network_ip = google_compute_address.rancher_internal.address
    access_config {
      nat_ip = google_compute_address.rancher.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker deploy

    # Mount persistent data disk
    DATA_DISK=/dev/disk/by-id/google-rancher-data
    if ! blkid $DATA_DISK 2>/dev/null; then
      mkfs.ext4 -m 0 $DATA_DISK
    fi
    mkdir -p /data
    mount $DATA_DISK /data
    echo "$DATA_DISK /data ext4 defaults 0 0" >> /etc/fstab

    # Rancher
    docker run -d --name rancher-server --restart unless-stopped \
      -p 80:80 -p 443:443 \
      -v /data/rancher:/var/lib/rancher \
      --privileged \
      rancher/rancher:v2.9.2
  EOF

  tags = ["shop-rancher", "shop"]
}