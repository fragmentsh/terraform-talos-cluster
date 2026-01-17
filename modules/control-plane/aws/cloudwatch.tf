# CloudWatch monitoring and alerting configuration

# -----------------------------------------------------------------------------
# ASG Instance Launch Failure Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "asg_launch_failure" {
  for_each = local.cloudwatch_config.create_alarms ? local.control_plane_nodes : {}

  alarm_name          = "${var.cluster_name}-${each.key}-launch-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupTotalInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Minimum"
  threshold           = 0 # Alert if instances drop below 1
  alarm_description   = "Alert if control plane node ${each.key} has no running instances"
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.control_plane[each.key].name
  }

  alarm_actions = local.cloudwatch_config.alarm_sns_topic_arn != null ? [local.cloudwatch_config.alarm_sns_topic_arn] : []

  tags = merge(
    local.resource_tags,
    try(var.cloudwatch.tags, {})
  )
}

# -----------------------------------------------------------------------------
# NLB Health Check Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  count = local.cloudwatch_config.create_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-unhealthy-control-plane"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert if any control plane nodes are unhealthy"

  dimensions = {
    TargetGroup  = aws_lb_target_group.k8s_api.arn_suffix
    LoadBalancer = aws_lb.control_plane.arn_suffix
  }

  alarm_actions = local.cloudwatch_config.alarm_sns_topic_arn != null ? [local.cloudwatch_config.alarm_sns_topic_arn] : []

  tags = merge(
    local.resource_tags,
    try(var.cloudwatch.tags, {})
  )
}
