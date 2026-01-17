# Lambda function for EBS volume and EIP attachment during ASG lifecycle events

# -----------------------------------------------------------------------------
# Lambda Function Package
# -----------------------------------------------------------------------------

data "archive_file" "attach_resources" {
  type        = "zip"
  source_file = "${path.module}/lambda/attach-resources.py"
  output_path = "${path.module}/lambda/attach-resources.zip"
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "attach_resources" {
  function_name = "${var.cluster_name}-attach-resources"
  description   = "Attaches EBS volumes and Elastic IPs to Talos control plane instances during ASG lifecycle events"

  filename         = data.archive_file.attach_resources.output_path
  source_code_hash = data.archive_file.attach_resources.output_base64sha256
  handler          = "attach-resources.lambda_handler"
  runtime          = local.lambda_config.runtime
  timeout          = local.lambda_config.timeout
  memory_size      = local.lambda_config.memory_size

  role = aws_iam_role.lambda_attach_resources.arn

  environment {
    variables = {
      CLUSTER_NAME       = var.cluster_name
      MAX_RETRY_ATTEMPTS = tostring(local.lambda_config.max_retry_attempts)
      RETRY_DELAY_BASE   = tostring(local.lambda_config.retry_delay_base)
    }
  }

  tags = merge(
    local.resource_tags,
    try(var.lambda.tags, {})
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_attach_resources
  ]
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda_attach_resources" {
  name              = "/aws/lambda/${var.cluster_name}-attach-resources"
  retention_in_days = local.lambda_config.log_retention

  tags = local.resource_tags
}

# -----------------------------------------------------------------------------
# EventBridge Rule to Trigger Lambda on ASG Lifecycle Events
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "asg_lifecycle" {
  name        = "${var.cluster_name}-control-plane-lifecycle"
  description = "Triggers Lambda on control plane ASG lifecycle events"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-launch Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [
        for k, v in local.control_plane_nodes : "${var.cluster_name}-control-plane-${k}"
      ]
    }
  })

  tags = local.resource_tags
}

resource "aws_cloudwatch_event_target" "asg_lifecycle" {
  rule      = aws_cloudwatch_event_rule.asg_lifecycle.name
  target_id = "attach-resources-lambda"
  arn       = aws_lambda_function.attach_resources.arn
}

# -----------------------------------------------------------------------------
# Lambda Permission for EventBridge
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.attach_resources.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_lifecycle.arn
}
