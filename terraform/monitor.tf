# ─── Monitoring VM ───
# Prometheus + Grafana + Loki được deploy qua CI/CD (SCP + docker-compose)

resource "google_compute_instance" "monitor" {
  name         = "shop-monitor"
  machine_type = var.monitor_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = var.monitor_disk_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_a.self_link
    network_ip = google_compute_address.monitor_internal.address
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io docker-compose
    systemctl enable docker
    usermod -aG docker deploy
  EOF

  tags = ["shop-monitor", "shop"]
}