# AWS Node Pools for Talos Kubernetes Cluster
# Ephemeral worker nodes with Auto Scaling Groups

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Flatten node pool instances for data source lookup
  # Similar pattern to GCP node-pools module
  node_pool_instances_pre = {
    for x in flatten([
      for pool_name, pool in var.node_pools : [
        for idx in range(pool.desired_capacity) : {
          pool = pool_name
          idx  = idx
        }
      ]
    ]) : "${x.pool}-${x.idx}" => x
  }

  # Collect IPs by pool (matches GCP structure)
  node_pools_instances_ips_by_pool = {
    for pool in keys(var.node_pools) : pool => [
      for k, n in local.node_pool_instances_pre : {
        public_ip  = try(data.aws_instance.node_pool_instance[k].public_ip, null)
        private_ip = data.aws_instance.node_pool_instance[k].private_ip
      }
      if n.pool == pool
    ]
  }

  # Flatten external IPs for output (matches GCP external_ips)
  node_pools_external_ips = flatten([
    for pool, ips in local.node_pools_instances_ips_by_pool : [
      for x in ips : x.public_ip
      if x.public_ip != null
    ]
  ])

  # Flatten private IPs for output (matches GCP private_ips)
  node_pools_private_ips = flatten([
    for pool, ips in local.node_pools_instances_ips_by_pool : [
      for x in ips : x.private_ip
    ]
  ])

  # Default root volume settings
  default_root_volume = {
    size_gb               = 50
    type                  = "gp3"
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = true
  }

  # Default instance metadata settings
  default_instance_metadata = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Default instance refresh settings
  default_instance_refresh = {
    min_healthy_percentage       = 90
    max_healthy_percentage       = 100
    instance_warmup              = 60
    skip_matching                = false
    auto_rollback                = false
    scale_in_protected_instances = "Ignore"
    standby_instances            = "Ignore"
  }
}

# -----------------------------------------------------------------------------
# Launch Templates
# -----------------------------------------------------------------------------

resource "aws_launch_template" "node_pool" {
  for_each = var.node_pools

  name_prefix            = "${var.cluster_name}-pool-${each.key}-"
  image_id               = var.talos_image_id
  instance_type          = each.value.instance_type
  update_default_version = coalesce(each.value.update_launch_template_default_version, true)

  iam_instance_profile {
    name = aws_iam_instance_profile.node_pool[each.key].name
  }

  network_interfaces {
    associate_public_ip_address = each.value.associate_public_ip
    security_groups             = [aws_security_group.node_pool[each.key].id]
    delete_on_termination       = true
  }

  # User data with Talos machine configuration
  user_data = base64encode(data.talos_machine_configuration.node_pool[each.key].machine_configuration)

  # Root volume (ephemeral, no persistent storage needed for workers)
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = coalesce(try(each.value.root_volume.size_gb, null), local.default_root_volume.size_gb)
      volume_type           = coalesce(try(each.value.root_volume.type, null), local.default_root_volume.type)
      iops                  = coalesce(try(each.value.root_volume.iops, null), local.default_root_volume.iops)
      throughput            = coalesce(try(each.value.root_volume.throughput, null), local.default_root_volume.throughput)
      encrypted             = coalesce(try(each.value.root_volume.encrypted, null), local.default_root_volume.encrypted)
      delete_on_termination = coalesce(try(each.value.root_volume.delete_on_termination, null), local.default_root_volume.delete_on_termination)
    }
  }

  # IMDSv2 configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = coalesce(try(each.value.instance_metadata.http_tokens, null), local.default_instance_metadata.http_tokens)
    http_put_response_hop_limit = coalesce(try(each.value.instance_metadata.http_put_response_hop_limit, null), local.default_instance_metadata.http_put_response_hop_limit)
    instance_metadata_tags      = coalesce(try(each.value.instance_metadata.instance_metadata_tags, null), local.default_instance_metadata.instance_metadata_tags)
  }

  # Instance tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      each.value.tags,
      {
        Name = "${var.cluster_name}-pool-${each.key}"
      }
    )
  }

  # Volume tags
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      each.value.tags,
      {
        Name = "${var.cluster_name}-pool-${each.key}"
      }
    )
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-pool-${each.key}-lt"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Groups
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "node_pool" {
  for_each = var.node_pools

  name                = "${var.cluster_name}-pool-${each.key}"
  vpc_zone_identifier = each.value.subnet_ids
  desired_capacity    = each.value.desired_capacity
  min_size            = each.value.min_size
  max_size            = each.value.max_size

  health_check_type         = each.value.health_check_type
  health_check_grace_period = each.value.health_check_grace_period
  default_cooldown          = each.value.default_cooldown

  launch_template {
    id      = aws_launch_template.node_pool[each.key].id
    version = aws_launch_template.node_pool[each.key].default_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = coalesce(try(each.value.instance_refresh.min_healthy_percentage, null), local.default_instance_refresh.min_healthy_percentage)
      max_healthy_percentage       = coalesce(try(each.value.instance_refresh.max_healthy_percentage, null), local.default_instance_refresh.max_healthy_percentage)
      instance_warmup              = coalesce(try(each.value.instance_refresh.instance_warmup, null), local.default_instance_refresh.instance_warmup)
      checkpoint_delay             = try(each.value.instance_refresh.checkpoint_delay, null)
      checkpoint_percentages       = try(each.value.instance_refresh.checkpoint_percentages, null)
      skip_matching                = coalesce(try(each.value.instance_refresh.skip_matching, null), local.default_instance_refresh.skip_matching)
      auto_rollback                = coalesce(try(each.value.instance_refresh.auto_rollback, null), local.default_instance_refresh.auto_rollback)
      scale_in_protected_instances = coalesce(try(each.value.instance_refresh.scale_in_protected_instances, null), local.default_instance_refresh.scale_in_protected_instances)
      standby_instances            = coalesce(try(each.value.instance_refresh.standby_instances, null), local.default_instance_refresh.standby_instances)

      dynamic "alarm_specification" {
        for_each = try(each.value.instance_refresh.alarm_specification, null) != null ? [each.value.instance_refresh.alarm_specification] : []
        content {
          alarms = alarm_specification.value.alarms
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-pool-${each.key}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = {
      for k, v in merge(var.tags, each.value.tags) : k => v
      if can(regex("^[0-9a-zA-Z\\-_+=,.@:]+$", k))
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = local.ca_tags_all[each.key]
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Data Sources - Instance Discovery
# -----------------------------------------------------------------------------

# Get all instances from each ASG
data "aws_instances" "node_pool" {
  depends_on = [aws_autoscaling_group.node_pool]
  for_each   = var.node_pools

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.node_pool[each.key].name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Get individual instance details for IP addresses
data "aws_instance" "node_pool_instance" {
  depends_on = [aws_autoscaling_group.node_pool]
  for_each   = local.node_pool_instances_pre

  instance_id = try(
    sort(data.aws_instances.node_pool[each.value.pool].ids)[each.value.idx],
    null
  )
}

# -----------------------------------------------------------------------------
# Talos Machine Configuration
# -----------------------------------------------------------------------------

data "talos_machine_configuration" "node_pool" {
  for_each = var.node_pools

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.kubernetes_api_url
  machine_type       = "worker"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_secrets    = var.talos_machine_secrets

  config_patches = concat(
    [
      yamlencode({
        machine = {
          network = {
            kubespan = {
              enabled = true
            }
          }
          kubelet = merge(
            {
              registerWithFQDN = true
              extraArgs = merge(
                {
                  cloud-provider             = "external"
                  rotate-server-certificates = true
                },
                length(each.value.labels) > 0 ? {
                  node-labels = join(",", [for k, v in each.value.labels : "${k}=${v}"])
                } : {}
              )
            },
            length(each.value.taints) > 0 ? {
              registerWithTaints = [
                for taint in each.value.taints : "${taint.key}=${taint.value}:${taint.effect}"
              ]
            } : {}
          )
        }
        cluster = {
          discovery = {
            enabled = true
          }
        }
      })
    ],
    each.value.config_patches
  )
}

# Apply Talos configuration to each instance
resource "talos_machine_configuration_apply" "node_pool" {
  depends_on = [aws_autoscaling_group.node_pool]
  for_each   = local.node_pool_instances_pre

  client_configuration        = var.talos_client_configuration
  machine_configuration_input = data.talos_machine_configuration.node_pool[each.value.pool].machine_configuration
  node                        = local.node_pools_instances_ips_by_pool[each.value.pool][each.value.idx].public_ip
  config_patches              = var.node_pools[each.value.pool].config_patches
}
