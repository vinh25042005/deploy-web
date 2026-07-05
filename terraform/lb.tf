# ─── HTTPS Load Balancer ───
# Self-signed cert (placeholder) → thay bằng google_managed_ssl_certificate khi có domain thật

# Private key + self-signed cert
resource "tls_private_key" "lb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "lb" {
  private_key_pem = tls_private_key.lb.private_key_pem

  subject {
    common_name = "techshop-lb.example.com"
  }

  validity_period_hours = 8760 # 1 năm

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Upload cert lên GCP
resource "google_compute_ssl_certificate" "lb" {
  name        = "techshop-lb-cert"
  private_key = tls_private_key.lb.private_key_pem
  certificate = tls_self_signed_cert.lb.cert_pem
}

# Global static IP cho Load Balancer
resource "google_compute_global_address" "lb" {
  name = "techshop-lb-ip"
}

# Health check
resource "google_compute_health_check" "frontend" {
  name = "frontend-health-check"

  http_health_check {
    port         = 3000
    request_path = "/"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Instance group (chứa frontend VM)
resource "google_compute_instance_group" "frontend" {
  name      = "frontend-instance-group"
  zone      = var.zone
  instances = [google_compute_instance.frontend.self_link]

  named_port {
    name = "http"
    port = 3000
  }
}

# Backend service
resource "google_compute_backend_service" "frontend" {
  name        = "frontend-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_instance_group.frontend.self_link
  }

  health_checks = [google_compute_health_check.frontend.self_link]
}

# URL map
resource "google_compute_url_map" "lb" {
  name            = "techshop-url-map"
  default_service = google_compute_backend_service.frontend.self_link
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "lb" {
  name             = "techshop-https-proxy"
  url_map          = google_compute_url_map.lb.self_link
  ssl_certificates = [google_compute_ssl_certificate.lb.self_link]
}

# Forwarding rule: HTTPS :443
resource "google_compute_global_forwarding_rule" "https" {
  name       = "techshop-https-forwarding"
  target     = google_compute_target_https_proxy.lb.self_link
  port_range = "443"
  ip_address = google_compute_global_address.lb.address
}
