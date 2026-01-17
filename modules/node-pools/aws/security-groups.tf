# Security Groups for Talos Node Pools
# Matches the firewall rules from GCP node-pools module

# -----------------------------------------------------------------------------
# Security Group (one per node pool)
# -----------------------------------------------------------------------------

resource "aws_security_group" "node_pool" {
  for_each = var.node_pools

  name        = "${var.cluster_name}-pool-${each.key}"
  description = "Security group for ${var.cluster_name} node pool ${each.key}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name                                        = "${var.cluster_name}-pool-${each.key}"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# -----------------------------------------------------------------------------
# Ingress Rules
# -----------------------------------------------------------------------------

# Talos API (port 50000)
resource "aws_vpc_security_group_ingress_rule" "talos_api" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "Talos API"
  from_port         = 50000
  to_port           = 50000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-talos-api"
  }
}

# Kubespan WireGuard (ports 51820-51871 UDP)
resource "aws_vpc_security_group_ingress_rule" "kubespan_wireguard" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "Kubespan WireGuard"
  from_port         = 51820
  to_port           = 51871
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-kubespan"
  }
}

# Kubernetes NodePort TCP (ports 30000-32767)
resource "aws_vpc_security_group_ingress_rule" "nodeport_tcp" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "Kubernetes NodePort TCP"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-nodeport-tcp"
  }
}

# Kubernetes NodePort UDP (ports 30000-32767)
resource "aws_vpc_security_group_ingress_rule" "nodeport_udp" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "Kubernetes NodePort UDP"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-nodeport-udp"
  }
}

# ICMP (for health checks and diagnostics)
resource "aws_vpc_security_group_ingress_rule" "icmp" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "ICMP"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-icmp"
  }
}

# -----------------------------------------------------------------------------
# Egress Rules
# -----------------------------------------------------------------------------

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = var.node_pools

  security_group_id = aws_security_group.node_pool[each.key].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.cluster_name}-pool-${each.key}-egress-all"
  }
}
