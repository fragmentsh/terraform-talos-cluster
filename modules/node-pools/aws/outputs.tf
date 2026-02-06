# Outputs for AWS Node Pools Module
# Matches the output structure of GCP node-pools module

# -----------------------------------------------------------------------------
# Auto Scaling Groups
# -----------------------------------------------------------------------------

output "node_pools" {
  description = "Node pool Auto Scaling Groups"
  value       = aws_autoscaling_group.node_pool
}

output "launch_templates" {
  description = "Node pool launch templates"
  value       = aws_launch_template.node_pool
}

# -----------------------------------------------------------------------------
# Instance Information
# -----------------------------------------------------------------------------

output "instances" {
  description = "Node pool instances by pool (similar to GCP instances output)"
  value       = data.aws_instances.node_pool
}

output "instances_ips_by_pools" {
  description = "Instance IPs organized by pool (matches GCP structure)"
  value       = local.node_pools_instances_ips_by_pool
}

# -----------------------------------------------------------------------------
# IP Addresses
# -----------------------------------------------------------------------------

output "external_ips" {
  description = "External (public) IP addresses of all node pool instances"
  value       = local.node_pools_external_ips
}

output "private_ips" {
  description = "Private IP addresses of all node pool instances"
  value       = local.node_pools_private_ips
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

output "security_groups" {
  description = "Security groups for node pools"
  value       = aws_security_group.node_pool
}

# -----------------------------------------------------------------------------
# IAM Resources
# -----------------------------------------------------------------------------

output "iam_roles" {
  description = "IAM roles for node pools"
  value       = aws_iam_role.node_pool
}

output "iam_instance_profiles" {
  description = "IAM instance profiles for node pools"
  value       = aws_iam_instance_profile.node_pool
}
