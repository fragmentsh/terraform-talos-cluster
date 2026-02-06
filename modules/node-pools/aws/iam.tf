# IAM Roles and Instance Profiles for Talos Node Pools
# Similar to GCP service accounts

# -----------------------------------------------------------------------------
# IAM Roles (one per node pool)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "node_pool" {
  for_each = var.node_pools

  name = "${var.cluster_name}-pool-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

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
# IAM Instance Profiles
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "node_pool" {
  for_each = var.node_pools

  name = "${var.cluster_name}-pool-${each.key}"
  role = aws_iam_role.node_pool[each.key].name

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-pool-${each.key}"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM Policies
# -----------------------------------------------------------------------------

# Basic policy for node pools
# Includes EC2 describe (for node discovery), ECR access, and CloudWatch logs
resource "aws_iam_role_policy" "node_pool" {
  for_each = var.node_pools

  name = "node-pool-policy"
  role = aws_iam_role.node_pool[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 describe permissions (for node discovery and cloud provider)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      # ECR access for pulling container images
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      # CloudWatch logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
