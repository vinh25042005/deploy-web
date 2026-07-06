# Static IP (Public)
resource "google_compute_address" "frontend" {
  name = "shop-frontend-ip"
  # Giữ static IP cho tương lai nếu cần, VM hiện dùng internal qua LB
}

# Static Internal IPs — không đổi khi rebuild VM
resource "google_compute_address" "db_internal" {
  name         = "shop-db-internal"
  address_type = "INTERNAL"
  address      = "10.20.1.2"
  subnetwork   = google_compute_subnetwork.subnet_a.self_link
}

resource "google_compute_address" "backend_internal" {
  name         = "shop-backend-internal"
  address_type = "INTERNAL"
  address      = "10.20.1.3"
  subnetwork   = google_compute_subnetwork.subnet_a.self_link
}

resource "google_compute_address" "frontend_internal" {
  name         = "shop-frontend-internal"
  address_type = "INTERNAL"
  address      = "10.20.1.4"
  subnetwork   = google_compute_subnetwork.subnet_a.self_link
}

resource "google_compute_address" "monitor_internal" {
  name         = "shop-monitor-internal"
  address_type = "INTERNAL"
  address      = "10.20.1.5"
  subnetwork   = google_compute_subnetwork.subnet_a.self_link
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
    network_ip = google_compute_address.db_internal.address
    # Internal-only: IAP SSH + Cloud NAT cho outbound (pull image)
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

    docker run -d --name node-exporter --restart always \
      --network host \
      -v /:/host:ro,rslave \
      prom/node-exporter:latest \
      --path.rootfs=/host

    # Promtail - gửi Docker logs về Loki
    cat > /opt/promtail-config.yml <<'PROMTAIL'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://10.20.1.5:3100/loki/api/v1/push
scrape_configs:
  - job_name: docker
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          host: shop-db
          __path__: /var/lib/docker/containers/*/*.log
PROMTAIL
    docker run -d --name promtail --restart always \
      -v /opt/promtail-config.yml:/etc/promtail/config.yml \
      -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
      grafana/promtail:latest \
      -config.file=/etc/promtail/config.yml
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
    network_ip = google_compute_address.backend_internal.address
    # Không có access_config → backend chỉ có internal IP
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker deploy
    docker run -d --name node-exporter --restart always \
      --network host \
      -v /:/host:ro,rslave \
      prom/node-exporter:latest \
      --path.rootfs=/host

    # Promtail - gửi Docker logs về Loki
    cat > /opt/promtail-config.yml <<'PROMTAIL'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://10.20.1.5:3100/loki/api/v1/push
scrape_configs:
  - job_name: docker
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          host: shop-backend
          __path__: /var/lib/docker/containers/*/*.log
PROMTAIL
    docker run -d --name promtail --restart always \
      -v /opt/promtail-config.yml:/etc/promtail/config.yml \
      -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
      grafana/promtail:latest \
      -config.file=/etc/promtail/config.yml
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
    network_ip = google_compute_address.frontend_internal.address
    # Internal-only: truy cập qua Load Balancer
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker deploy
    docker run -d --name node-exporter --restart always \
      --network host \
      -v /:/host:ro,rslave \
      prom/node-exporter:latest \
      --path.rootfs=/host

    # Promtail - gửi Docker logs về Loki
    cat > /opt/promtail-config.yml <<'PROMTAIL'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://10.20.1.5:3100/loki/api/v1/push
scrape_configs:
  - job_name: docker
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          host: shop-frontend
          __path__: /var/lib/docker/containers/*/*.log
PROMTAIL
    docker run -d --name promtail --restart always \
      -v /opt/promtail-config.yml:/etc/promtail/config.yml \
      -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
      grafana/promtail:latest \
      -config.file=/etc/promtail/config.yml
  EOF

  tags = ["shop-frontend", "shop"]
}