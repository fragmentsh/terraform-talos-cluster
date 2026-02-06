output "instances" {
  description = "Control plane instance information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      id         = aws_instance.control_plane[k].id
      subnet_id  = v.subnet_id
      private_ip = v.private_ip
      public_ip  = v.enable_eip ? aws_eip.control_plane[k].public_ip : null
    }
  }
}

output "network_interfaces" {
  description = "Network interface information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      id         = aws_network_interface.control_plane[k].id
      private_ip = aws_network_interface.control_plane[k].private_ip
    }
  }
}

output "elastic_ips" {
  description = "Elastic IP information"
  value = {
    for k, v in local.control_plane_nodes : k => {
      id        = v.enable_eip ? aws_eip.control_plane[k].id : null
      public_ip = v.enable_eip ? aws_eip.control_plane[k].public_ip : null
    }
    if v.enable_eip
  }
}

output "external_ips" {
  description = "External IP addresses of control plane instances (EIPs)"
  value = [
    for k, v in local.control_plane_nodes : aws_eip.control_plane[k].public_ip
    if v.enable_eip
  ]
}

output "private_ips" {
  description = "Private IP addresses of control plane instances"
  value = [
    for k in local.control_plane_nodes_keys : aws_network_interface.control_plane[k].private_ip
  ]
}

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

output "irsa_oidc_provider_arn" {
  description = "IRSA OIDC provider ARN"
  value       = var.irsa.enabled ? aws_iam_openid_connect_provider.irsa_oidc[0].arn : null
}

output "irsa_oidc_issuer_url" {
  description = "IRSA OIDC issuer URL"
  value       = var.irsa.enabled ? "https://${local.issuer_hostpath}" : null
}

output "irsa_private_key" {
  description = "IRSA private key for service account signing"
  value       = var.irsa.enabled ? tls_private_key.irsa_oidc[0].private_key_pem : null
  sensitive   = true
}

output "ephemeral_volumes" {
  description = "EBS volumes for Talos ephemeral partition (/var)"
  value = {
    for k, v in local.control_plane_nodes : k => {
      id   = aws_ebs_volume.ephemeral[k].id
      size = aws_ebs_volume.ephemeral[k].size
      az   = aws_ebs_volume.ephemeral[k].availability_zone
    } if v.ephemeral_volume.enabled
  }
}

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

output "kubeconfig" {
  description = "Kubernetes kubeconfig for kubectl access"
  value       = talos_cluster_kubeconfig.talos.kubeconfig_raw
  sensitive   = true
}

output "talos_ami" {
  description = "Talos AMI used for control plane instances"
  value = {
    id = var.talos_image_id
  }
}
