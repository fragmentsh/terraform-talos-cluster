# Auto Scaling Groups and Launch Templates for control plane instances

# -----------------------------------------------------------------------------
# Launch Templates (one per control plane node for unique hostname config)
# -----------------------------------------------------------------------------

resource "aws_launch_template" "control_plane" {
  for_each = local.control_plane_nodes

  name_prefix            = "${var.cluster_name}-control-plane-${each.key}-"
  image_id               = var.talos_image_id
  instance_type          = each.value.instance_type
  update_default_version = each.value.update_launch_template_default_version

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = local.root_volume_config.size_gb
      volume_type           = local.root_volume_config.type
      iops                  = local.root_volume_config.type == "gp3" || local.root_volume_config.type == "io1" || local.root_volume_config.type == "io2" ? local.root_volume_config.iops : null
      throughput            = local.root_volume_config.type == "gp3" ? local.root_volume_config.throughput : null
      encrypted             = local.root_volume_config.encrypted
      kms_key_id            = local.root_volume_config.kms_key_id
      delete_on_termination = local.root_volume_config.delete_on_termination
    }
  }

  metadata_options {
    http_tokens                 = local.metadata_config.http_tokens
    http_put_response_hop_limit = local.metadata_config.http_put_response_hop_limit
    instance_metadata_tags      = local.metadata_config.instance_metadata_tags
    http_endpoint               = "enabled"
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.control_plane.name
  }

  network_interfaces {
    associate_public_ip_address = try(var.control_plane.associate_public_ip, true)
    security_groups             = [aws_security_group.control_plane.id]
    delete_on_termination       = true
  }

  user_data = base64encode(data.talos_machine_configuration.control_plane[each.key].machine_configuration)

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.instance_tags,
      {
        Name = "${var.cluster_name}-control-plane-${each.key}"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.instance_tags,
      {
        Name       = "${var.cluster_name}-control-plane-${each.key}-root"
        VolumeType = "root"
      }
    )
  }

  tag_specifications {
    resource_type = "network-interface"

    tags = local.instance_tags
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.resource_tags
}

# -----------------------------------------------------------------------------
# Auto Scaling Groups (one per control plane node)
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "control_plane" {
  for_each = local.control_plane_nodes

  name             = "${var.cluster_name}-control-plane-${each.key}"
  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  # Single AZ per ASG (required for EBS volume attachment)
  vpc_zone_identifier = [each.value.subnet_id]

  launch_template {
    id      = aws_launch_template.control_plane[each.key].id
    version = aws_launch_template.control_plane[each.key].default_version
  }

  # Health check configuration
  health_check_type         = try(var.control_plane.health_check_type, "EC2")
  health_check_grace_period = try(var.control_plane.health_check_grace_period, 300)
  default_cooldown          = try(var.control_plane.default_cooldown, 300)
  wait_for_capacity_timeout = try(var.control_plane.wait_for_capacity_timeout, "10m")

  # Protect instances from scale-in
  protect_from_scale_in = try(var.control_plane.protect_from_scale_in, true)

  # Target group attachment for load balancer
  target_group_arns = [
    aws_lb_target_group.k8s_api.arn,
    aws_lb_target_group.talos_api.arn
  ]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = 0
      max_healthy_percentage       = 100
      instance_warmup              = try(var.control_plane.instance_warmup, 60)
      scale_in_protected_instances = "Refresh"
    }
  }

  initial_lifecycle_hook {
    name                 = "attach-resources"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    default_result       = "ABANDON"
    heartbeat_timeout    = local.lambda_config.timeout + 60
    notification_metadata = jsonencode({
      cluster_name = var.cluster_name
      slot         = each.value.slot
    })
  }

  dynamic "tag" {
    for_each = merge(
      local.instance_tags,
      var.control_plane.tags,
      each.value.tags,
      {
        Name = "${var.cluster_name}-control-plane-${each.key}"
        Slot = tostring(each.value.slot)
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_ebs_volume.ephemeral,
    aws_lambda_function.attach_resources
  ]
}

# -----------------------------------------------------------------------------
# ASG Lifecycle Hooks (one per control plane ASG)
# Separate resource to ensure hook persists for all instance launches
# (initial_lifecycle_hook only guarantees hook exists at ASG creation)
# -----------------------------------------------------------------------------

resource "aws_autoscaling_lifecycle_hook" "attach_resources" {
  for_each = local.control_plane_nodes

  name                   = "attach-resources"
  autoscaling_group_name = aws_autoscaling_group.control_plane[each.key].name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result         = "ABANDON"
  heartbeat_timeout      = local.lambda_config.timeout + 60

  notification_metadata = jsonencode({
    cluster_name = var.cluster_name
    slot         = each.value.slot
  })
}
