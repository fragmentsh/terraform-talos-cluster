locals {
  control_plane_count = length(var.control_plane.nodes)

  control_plane_nodes = {
    for k, v in var.control_plane.nodes :
    k => {
      index = tonumber(k)
      slot  = tonumber(k)

      instance_type                          = coalesce(v.instance_type, var.control_plane.instance_type)
      update_launch_template_default_version = coalesce(v.update_launch_template_default_version, false)
      tags                                   = coalesce(v.tags, {})

      config_patches = concat(
        var.control_plane.config_patches,
        coalesce(v.config_patches, [])
      )

      az        = coalesce(v.availability_zone, var.availability_zones[tonumber(k) % length(var.availability_zones)])
      subnet_id = var.subnet_ids[coalesce(v.availability_zone, var.availability_zones[tonumber(k) % length(var.availability_zones)])]
    }
  }

  etcd_member_list = join(",", [for k in keys(var.control_plane.nodes) : k])

  # Resource tags (includes kubernetes.io - for non-ASG-propagated resources)
  resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  # Instance tags (simple tags only - safe for ASG propagation to instances)
  instance_tags = merge(
    var.tags,
    {
      Cluster = var.cluster_name
      Role    = "control-plane"
    }
  )

  # Volume tags (includes both kubernetes.io for tools and simple tags for Lambda)
  volume_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      Cluster                                     = var.cluster_name
      Role                                        = "control-plane"
    }
  )

  root_volume_config = {
    size_gb               = try(var.control_plane.root_volume.size_gb, 20)
    type                  = try(var.control_plane.root_volume.type, "gp3")
    iops                  = try(var.control_plane.root_volume.iops, 3000)
    throughput            = try(var.control_plane.root_volume.throughput, 125)
    encrypted             = try(var.control_plane.root_volume.encrypted, true)
    kms_key_id            = try(var.control_plane.root_volume.kms_key_id, null)
    delete_on_termination = try(var.control_plane.root_volume.delete_on_termination, true)
  }

  ephemeral_volume_config = {
    size_gb    = try(var.control_plane.ephemeral_volume.size_gb, 50)
    type       = try(var.control_plane.ephemeral_volume.type, "gp3")
    iops       = try(var.control_plane.ephemeral_volume.iops, 3000)
    throughput = try(var.control_plane.ephemeral_volume.throughput, 125)
    encrypted  = try(var.control_plane.ephemeral_volume.encrypted, true)
    kms_key_id = try(var.control_plane.ephemeral_volume.kms_key_id, null)
  }

  # Instance metadata configuration with defaults (IMDSv2)
  metadata_config = {
    http_tokens                 = try(var.control_plane.instance_metadata.http_tokens, "required")
    http_put_response_hop_limit = try(var.control_plane.instance_metadata.http_put_response_hop_limit, 2)
    instance_metadata_tags      = try(var.control_plane.instance_metadata.instance_metadata_tags, "enabled")
  }

  nlb_config = {
    internal                         = try(var.load_balancer.internal, false)
    enable_cross_zone_load_balancing = try(var.load_balancer.enable_cross_zone_load_balancing, true)
    enable_deletion_protection       = try(var.load_balancer.enable_deletion_protection, true)
    deregistration_delay             = try(var.load_balancer.deregistration_delay, 30)
    health_check = {
      enabled             = try(var.load_balancer.health_check.enabled, true)
      interval            = try(var.load_balancer.health_check.interval, 10)
      healthy_threshold   = try(var.load_balancer.health_check.healthy_threshold, 2)
      unhealthy_threshold = try(var.load_balancer.health_check.unhealthy_threshold, 2)
      timeout             = try(var.load_balancer.health_check.timeout, 5)
      port                = try(var.load_balancer.health_check.port, 6443)
      protocol            = try(var.load_balancer.health_check.protocol, "TCP")
    }
    talos_api = {
      deregistration_delay = try(var.load_balancer.talos_api.deregistration_delay, 10)
      health_check = {
        enabled             = try(var.load_balancer.talos_api.health_check.enabled, true)
        interval            = try(var.load_balancer.talos_api.health_check.interval, 10)
        healthy_threshold   = try(var.load_balancer.talos_api.health_check.healthy_threshold, 2)
        unhealthy_threshold = try(var.load_balancer.talos_api.health_check.unhealthy_threshold, 2)
      }
    }
  }

  # Lambda configuration with defaults
  lambda_config = {
    timeout            = try(var.lambda.timeout, 300)
    memory_size        = try(var.lambda.memory_size, 256)
    runtime            = try(var.lambda.runtime, "python3.12")
    log_retention      = try(var.lambda.log_retention, 7)
    max_retry_attempts = try(var.lambda.max_retry_attempts, 5)
    retry_delay_base   = try(var.lambda.retry_delay_base, 2)
  }

  # CloudWatch configuration with defaults
  cloudwatch_config = {
    create_alarms             = try(var.cloudwatch.create_alarms, true)
    alarm_sns_topic_arn       = try(var.cloudwatch.alarm_sns_topic_arn, null)
    lambda_error_threshold    = try(var.cloudwatch.lambda_error_threshold, 0)
    lambda_duration_threshold = try(var.cloudwatch.lambda_duration_threshold, 240000)
  }

  # Security group configuration with defaults
  security_group_config = {
    api_ingress_cidr_blocks  = try(var.security_group.api_ingress_cidr_blocks, ["0.0.0.0/0"])
    additional_ingress_rules = try(var.security_group.additional_ingress_rules, [])
    additional_egress_rules  = try(var.security_group.additional_egress_rules, [])
  }


}
