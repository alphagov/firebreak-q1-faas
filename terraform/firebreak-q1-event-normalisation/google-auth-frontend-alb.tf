resource "aws_lb" "event-normalisation-alb" {
  name               = "event-normalisation-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.event-normalisation-alb-ingress.id}", "${aws_security_group.event-normalisation-alb-egress.id}"]
  subnets            = ["${aws_subnet.alb-frontend-subnet1-AZ-A.id}", "${aws_subnet.alb-frontend-subnet2-AZ-B.id}"]

  #  access_logs {
  #    bucket  = "${var.alb_access_logs}"
  #    enabled = true
  #  }

  enable_deletion_protection = true
  tags {
    Name      = "event-normalisation-alb"
    Product   = "alb"
    ManagedBy = "terraform"
  }
}

resource "aws_lb_target_group" "event-normalisation-tg" {
  name        = "target-group-event-normalisation"
  target_type = "lambda"

  health_check {
    path     = "/__gtg"
    matcher  = "200"
    interval = "60"
  }
}

resource "aws_lb_listener" "event-normalisation-listner" {
  load_balancer_arn = "${aws_lb.event-normalisation-alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-1-2017-01"
  certificate_arn   = "${var.alb_certificate_arn}"

  default_action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint      = "https://accounts.google.com/o/oauth2/v2/auth"
      client_id                   = "${var.oidc_client_id}"
      client_secret               = "${var.oidc_client_secret}"
      issuer                      = "https://accounts.google.com"
      token_endpoint              = "https://oauth2.googleapis.com/token"
      user_info_endpoint          = "https://openidconnect.googleapis.com/v1/userinfo"
      on_unauthenticated_request  = "authenticate"
    }
  }

  default_action {
    target_group_arn = "${aws_lb_target_group.event-normalisation-tg.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "route_gtg" {
  listener_arn = "${aws_lb_listener.event-normalisation-listner.arn}"
  priority     = 100

  action {
    target_group_arn = "${aws_lb_target_group.event-normalisation-tg.arn}"
    type             = "forward"
  }

  condition {
    field  = "path-pattern"
    values = ["/__gtg"]
  }
}

resource "aws_lb_listener_rule" "route_login" {
  listener_arn = "${aws_lb_listener.event-normalisation-listner.arn}"
  priority     = 200

  action {
    target_group_arn = "${aws_lb_target_group.event-normalisation-tg.arn}"
    type             = "forward"
  }

  condition {
    field  = "path-pattern"
    values = ["/login"]
  }
}

resource "aws_lb_listener_rule" "route_assets" {
  listener_arn = "${aws_lb_listener.event-normalisation-listner.arn}"
  priority     = 300

  action {
    target_group_arn = "${aws_lb_target_group.event-normalisation-tg.arn}"
    type             = "forward"
  }

  condition {
    field  = "path-pattern"
    values = ["/assets/*"]
  }
}

resource "aws_lb_listener_rule" "route_unauthenticated" {
  listener_arn = "${aws_lb_listener.event-normalisation-listner.arn}"
  priority     = 400

  action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint      = "https://accounts.google.com/o/oauth2/v2/auth"
      client_id                   = "${var.oidc_client_id}"
      client_secret               = "${var.oidc_client_secret}"
      issuer                      = "https://accounts.google.com"
      token_endpoint              = "https://oauth2.googleapis.com/token"
      user_info_endpoint          = "https://openidconnect.googleapis.com/v1/userinfo"
      on_unauthenticated_request  = "allow"
    }
  }

  action {
    type             = "redirect"

    redirect {
      path             = "/login"
      port             = "443"
      protocol         = "HTTPS"
      status_code      = "HTTP_302"
    }
  }

  condition {
    field  = "path-pattern"
    values = ["*"]
  }
}
