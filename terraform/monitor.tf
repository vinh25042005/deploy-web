# ─── Monitoring VM ───
# Chạy Prometheus + Grafana + Node Exporter
# Truy cập Grafana qua SSH tunnel: gcloud compute ssh shop-monitor -- -L 3333:localhost:3333

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
    # Internal-only — truy cập Grafana qua SSH tunnel hoặc LB
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y docker.io docker-compose
    systemctl enable docker
    usermod -aG docker deploy

    # Tạo cấu trúc thư mục monitoring
    mkdir -p /opt/monitoring/prometheus /opt/monitoring/grafana

    # docker-compose.yml
    cat > /opt/monitoring/docker-compose.yml <<'YAML'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    ports:
      - "3333:3000"
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    command:
      - '--path.rootfs=/host'
    network_mode: host
    pid: host
    volumes:
      - /:/host:ro,rslave
volumes:
  prometheus_data:
  grafana_data:
YAML

    # prometheus.yml
    cat > /opt/monitoring/prometheus/prometheus.yml <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node-monitor'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'node-backend'
    static_configs:
      - targets: ['10.20.1.3:9100']
  - job_name: 'node-frontend'
    static_configs:
      - targets: ['10.20.1.4:9100']
  - job_name: 'node-db'
    static_configs:
      - targets: ['10.20.1.2:9100']
YAML

    # datasources.yml
    cat > /opt/monitoring/grafana/datasources.yml <<'YAML'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
YAML

    # Khởi động monitoring stack
    cd /opt/monitoring && docker-compose up -d
  EOF

  tags = ["shop-monitor", "shop"]
}