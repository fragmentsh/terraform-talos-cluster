# -----------------------------------------------------------------------------
# Data Source for Control Plane Instances
# Used to get instance IPs after ASGs create them
# -----------------------------------------------------------------------------

data "aws_instances" "control_plane" {
  depends_on = [aws_autoscaling_group.control_plane]

  filter {
    name   = "tag:Cluster"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:Role"
    values = ["control-plane"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending"]
  }
}

data "aws_instances" "control_plane_by_node" {
  for_each   = local.control_plane_nodes
  depends_on = [aws_autoscaling_group.control_plane]

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-control-plane-${each.key}"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending"]
  }
}

data "aws_instance" "control_plane" {
  for_each    = local.control_plane_nodes
  depends_on  = [aws_autoscaling_group.control_plane]
  instance_id = try(data.aws_instances.control_plane_by_node[each.key].ids[0], null)
}

# -----------------------------------------------------------------------------
# Availability Zone Validation
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# Validate that all specified AZs are valid
resource "terraform_data" "validate_azs" {
  lifecycle {
    precondition {
      condition = alltrue([
        for az in var.availability_zones :
        contains(data.aws_availability_zones.available.names, az)
      ])
      error_message = "One or more specified availability zones are not valid in this region: ${join(", ", var.availability_zones)}"
    }
  }
}

# Validate subnet_ids match availability_zones
resource "terraform_data" "validate_subnets" {
  lifecycle {
    precondition {
      condition = alltrue([
        for az in var.availability_zones :
        contains(keys(var.subnet_ids), az)
      ])
      error_message = "All availability zones must have a corresponding subnet_id"
    }
  }
}
