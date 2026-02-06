resource "aws_iam_role" "control_plane" {
  name = "${var.cluster_name}-control-plane"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.resource_tags
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.cluster_name}-control-plane"
  role = aws_iam_role.control_plane.name

  tags = local.resource_tags
}

# Minimal IAM policy for control plane instances
#
# Since we use IRSA (IAM Roles for Service Accounts), AWS integrations like
# EBS CSI Driver, Load Balancer Controller, and Cluster Autoscaler get their
# permissions via pod-level IAM roles, NOT instance roles.
#
# The control plane instances only need minimal permissions for:
# - Talos Cloud Controller Manager to identify the node/region
# - Basic instance metadata operations
#
resource "aws_iam_role_policy" "control_plane" {
  name = "${var.cluster_name}-control-plane"
  role = aws_iam_role.control_plane.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TalosCloudControllerManager"
        Effect = "Allow"
        Action = [
          # Required for Talos CCM to identify node and populate node labels
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstanceTopology"
        ]
        Resource = "*"
      }
    ]
  })
}
