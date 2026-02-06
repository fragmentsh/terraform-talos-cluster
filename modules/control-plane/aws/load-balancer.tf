resource "aws_lb" "control_plane" {
  name               = "${var.cluster_name}-control-plane"
  internal           = var.nlb.internal
  load_balancer_type = "network"
  subnets            = local.nlb_subnet_ids

  enable_cross_zone_load_balancing = var.nlb.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.nlb.enable_deletion_protection

  tags = merge(
    local.resource_tags,
    try(var.nlb.tags, {}),
    {
      Name = "${var.cluster_name}-control-plane"
    }
  )
}

resource "aws_lb_target_group" "k8s_api" {
  name     = "${var.cluster_name}-k8s-api"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  deregistration_delay = var.nlb.k8s_api.deregistration_delay

  health_check {
    enabled             = var.nlb.k8s_api.health_check.enabled
    protocol            = var.nlb.k8s_api.health_check.protocol
    port                = var.nlb.k8s_api.health_check.port
    interval            = var.nlb.k8s_api.health_check.interval
    healthy_threshold   = var.nlb.k8s_api.health_check.healthy_threshold
    unhealthy_threshold = var.nlb.k8s_api.health_check.unhealthy_threshold
  }

  tags = merge(
    local.resource_tags,
    {
      Name = "${var.cluster_name}-k8s-api"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.control_plane.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }

  tags = local.resource_tags
}

resource "aws_lb_target_group" "talos_api" {
  name     = "${var.cluster_name}-talos-api"
  port     = 50000
  protocol = "TCP"
  vpc_id   = var.vpc_id

  deregistration_delay = var.nlb.talos_api.deregistration_delay

  health_check {
    enabled             = var.nlb.talos_api.health_check.enabled
    protocol            = "TCP"
    port                = "50000"
    interval            = var.nlb.talos_api.health_check.interval
    healthy_threshold   = var.nlb.talos_api.health_check.healthy_threshold
    unhealthy_threshold = var.nlb.talos_api.health_check.unhealthy_threshold
  }

  tags = merge(
    local.resource_tags,
    {
      Name = "${var.cluster_name}-talos-api"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "talos_api" {
  load_balancer_arn = aws_lb.control_plane.arn
  port              = 50000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.talos_api.arn
  }

  tags = local.resource_tags
}
