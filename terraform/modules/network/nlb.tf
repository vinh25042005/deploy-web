# NLB cho ingress-nginx nodes
# NLB targets the 2 ingress EC2 instances on port 80 & 443

resource "aws_lb" "ingress_nlb" {
  name               = "${var.project_name}-ingress-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_cross_zone_load_balancing = true

  tags = { Name = "${var.project_name}-ingress-nlb" }
}

resource "aws_lb_target_group" "ingress_http" {
  name     = "${var.project_name}-ingress-http"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = { Name = "${var.project_name}-ingress-http" }
}

resource "aws_lb_target_group" "ingress_https" {
  name     = "${var.project_name}-ingress-https"
  port     = 443
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "443"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = { Name = "${var.project_name}-ingress-https" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ingress_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ingress_nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_https.arn
  }
}
