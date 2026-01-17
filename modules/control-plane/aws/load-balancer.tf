# Network Load Balancer for Kubernetes API endpoint

# -----------------------------------------------------------------------------
# Network Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "control_plane" {
  name               = "${var.cluster_name}-k8s-api"
  internal           = local.nlb_config.internal
  load_balancer_type = "network"
  subnets            = [for az, subnet_id in var.subnet_ids : subnet_id]

  enable_cross_zone_load_balancing = local.nlb_config.enable_cross_zone_load_balancing
  enable_deletion_protection       = local.nlb_config.enable_deletion_protection

  tags = merge(
    local.resource_tags,
    try(var.load_balancer.tags, {}),
    {
      Name = "${var.cluster_name}-k8s-api"
    }
  )
}

# -----------------------------------------------------------------------------
# Target Group for Kubernetes API (6443)
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "k8s_api" {
  name     = "${var.cluster_name}-k8s-api"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  deregistration_delay = local.nlb_config.deregistration_delay

  health_check {
    enabled             = local.nlb_config.health_check.enabled
    protocol            = local.nlb_config.health_check.protocol
    port                = tostring(local.nlb_config.health_check.port)
    interval            = local.nlb_config.health_check.interval
    healthy_threshold   = local.nlb_config.health_check.healthy_threshold
    unhealthy_threshold = local.nlb_config.health_check.unhealthy_threshold
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

# -----------------------------------------------------------------------------
# Listener for Kubernetes API (6443)
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Target Group for Talos API (50000)
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "talos_api" {
  name     = "${var.cluster_name}-talos-api"
  port     = 50000
  protocol = "TCP"
  vpc_id   = var.vpc_id

  deregistration_delay = local.nlb_config.talos_api.deregistration_delay

  health_check {
    enabled             = local.nlb_config.talos_api.health_check.enabled
    protocol            = "TCP"
    port                = "50000"
    interval            = local.nlb_config.talos_api.health_check.interval
    healthy_threshold   = local.nlb_config.talos_api.health_check.healthy_threshold
    unhealthy_threshold = local.nlb_config.talos_api.health_check.unhealthy_threshold
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

# -----------------------------------------------------------------------------
# Listener for Talos API (50000)
# -----------------------------------------------------------------------------

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
