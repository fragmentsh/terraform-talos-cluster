resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  for_each = var.cloudwatch.create_alarms ? local.control_plane_nodes : {}

  alarm_name          = "${var.cluster_name}-${each.key}-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert if control plane node ${each.key} fails status checks"

  dimensions = {
    InstanceId = aws_instance.control_plane[each.key].id
  }

  alarm_actions = var.cloudwatch.alarm_sns_topic_arn != null ? [var.cloudwatch.alarm_sns_topic_arn] : []

  tags = merge(
    local.resource_tags,
    try(var.cloudwatch.tags, {})
  )
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  count = var.cloudwatch.create_alarms ? 1 : 0

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

  alarm_actions = var.cloudwatch.alarm_sns_topic_arn != null ? [var.cloudwatch.alarm_sns_topic_arn] : []

  tags = merge(
    local.resource_tags,
    try(var.cloudwatch.tags, {})
  )
}
