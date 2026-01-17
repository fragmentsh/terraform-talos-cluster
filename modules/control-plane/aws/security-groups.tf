# Security groups for control plane instances

resource "aws_security_group" "control_plane" {
  name        = "${var.cluster_name}-control-plane"
  description = "Security group for Talos control plane nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    local.resource_tags,
    try(var.security_group.tags, {}),
    {
      Name = "${var.cluster_name}-control-plane"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Ingress Rules
# -----------------------------------------------------------------------------

# Kubernetes API (6443)
resource "aws_security_group_rule" "k8s_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = local.security_group_config.api_ingress_cidr_blocks
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubernetes API server"
}

# Talos API (50000)
resource "aws_security_group_rule" "talos_api" {
  type              = "ingress"
  from_port         = 50000
  to_port           = 50000
  protocol          = "tcp"
  cidr_blocks       = local.security_group_config.api_ingress_cidr_blocks
  security_group_id = aws_security_group.control_plane.id
  description       = "Talos API"
}

# Talos trustd (50001)
resource "aws_security_group_rule" "talos_trustd" {
  type              = "ingress"
  from_port         = 50001
  to_port           = 50001
  protocol          = "tcp"
  cidr_blocks       = local.security_group_config.api_ingress_cidr_blocks
  security_group_id = aws_security_group.control_plane.id
  description       = "Talos trustd"
}

# Kubespan WireGuard (UDP 51820)
resource "aws_security_group_rule" "kubespan_wireguard" {
  type              = "ingress"
  from_port         = 51820
  to_port           = 51820
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubespan WireGuard"
}

# Kubespan discovery (UDP 51871)
resource "aws_security_group_rule" "kubespan_discovery" {
  type              = "ingress"
  from_port         = 51871
  to_port           = 51871
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubespan discovery"
}

# Allow all traffic within control plane security group
resource "aws_security_group_rule" "internal_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.control_plane.id
  security_group_id        = aws_security_group.control_plane.id
  description              = "Allow all traffic within control plane"
}

# ICMP (ping) for diagnostics
resource "aws_security_group_rule" "icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.control_plane.id
  description       = "ICMP for diagnostics"
}

# Additional ingress rules (user-defined)
resource "aws_security_group_rule" "additional_ingress" {
  for_each = {
    for idx, rule in local.security_group_config.additional_ingress_rules :
    idx => rule
  }

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = aws_security_group.control_plane.id
  description       = each.value.description
}

# -----------------------------------------------------------------------------
# Egress Rules
# -----------------------------------------------------------------------------

# Allow all outbound traffic by default
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.control_plane.id
  description       = "Allow all outbound traffic"
}

# Additional egress rules (user-defined)
resource "aws_security_group_rule" "additional_egress" {
  for_each = {
    for idx, rule in local.security_group_config.additional_egress_rules :
    idx => rule
  }

  type              = "egress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = aws_security_group.control_plane.id
  description       = each.value.description
}
