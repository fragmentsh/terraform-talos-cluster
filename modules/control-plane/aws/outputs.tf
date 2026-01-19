# Module outputs - matching GCP module outputs for consistency

# -----------------------------------------------------------------------------
# Instance Outputs
# -----------------------------------------------------------------------------

output "instances" {
  description = "Control plane instance information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      az        = v.az
      subnet_id = v.subnet_id
      asg_name  = aws_autoscaling_group.control_plane[k].name
    }
  }
}

output "instance_templates" {
  description = "Launch template information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      id      = aws_launch_template.control_plane[k].id
      name    = aws_launch_template.control_plane[k].name
      version = aws_launch_template.control_plane[k].latest_version
    }
  }
}

output "external_ips" {
  description = "External IP addresses of control plane instances (ephemeral)"
  value       = data.aws_instances.control_plane.public_ips
}

output "private_ips" {
  description = "Private IP addresses of control plane instances"
  value       = data.aws_instances.control_plane.private_ips
}

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

output "kubernetes_api_ip" {
  description = "Kubernetes API endpoint IP address (NLB DNS name)"
  value       = aws_lb.control_plane.dns_name
}

output "kubernetes_api_url" {
  description = "Kubernetes API endpoint URL"
  value       = "https://${aws_lb.control_plane.dns_name}:6443"
}



output "load_balancer" {
  description = "Network Load Balancer information"
  value = {
    arn      = aws_lb.control_plane.arn
    dns_name = aws_lb.control_plane.dns_name
    zone_id  = aws_lb.control_plane.zone_id
  }
}

output "irsa_private_key" {
  value     = tls_private_key.irsa_oidc[0].private_key_pem
  sensitive = true
}

# -----------------------------------------------------------------------------
# ASG Outputs
# -----------------------------------------------------------------------------

output "asgs" {
  description = "Auto Scaling Group information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      name = aws_autoscaling_group.control_plane[k].name
      arn  = aws_autoscaling_group.control_plane[k].arn
      az   = v.az
    }
  }
}

# -----------------------------------------------------------------------------
# Security Outputs
# -----------------------------------------------------------------------------

output "security_group_id" {
  description = "Security group ID for control plane instances"
  value       = aws_security_group.control_plane.id
}

output "iam_role_arn" {
  description = "IAM role ARN for control plane instances"
  value       = aws_iam_role.control_plane.arn
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name for control plane instances"
  value       = aws_iam_instance_profile.control_plane.name
}

# -----------------------------------------------------------------------------
# Talos Outputs
# -----------------------------------------------------------------------------

output "talos_machine_secrets" {
  description = "Talos machine secrets (sensitive)"
  value       = talos_machine_secrets.talos.machine_secrets
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Talos client configuration for talosctl"
  value       = talos_machine_secrets.talos.client_configuration
  sensitive   = true
}

#output "kubeconfig" {
#  description = "Kubernetes kubeconfig for kubectl access"
#  value       = talos_cluster_kubeconfig.talos.kubeconfig_raw
#  sensitive   = true
#}

# -----------------------------------------------------------------------------
# AMI Output
# -----------------------------------------------------------------------------

output "talos_ami" {
  description = "Talos AMI used for control plane instances"
  value = {
    id = var.talos_image_id
  }
}
