output "control_plane_api_url" {
  description = "Kubernetes API endpoint URL"
  value       = module.control_plane.kubernetes_api_url
}

output "control_plane_instances" {
  description = "Control plane instance information"
  value       = module.control_plane.instances
}

output "control_plane_external_ips" {
  description = "Control plane external IP addresses (EIPs)"
  value       = module.control_plane.external_ips
}

output "control_plane_private_ips" {
  description = "Control plane private IP addresses"
  value       = module.control_plane.private_ips
}

output "kubeconfig" {
  description = "Kubernetes kubeconfig for kubectl access"
  value       = module.control_plane.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.talos.talos_config
  sensitive   = true
}

output "load_balancer" {
  description = "Network Load Balancer information"
  value       = module.control_plane.load_balancer
}

output "irsa_oidc_provider_arn" {
  description = "IRSA OIDC provider ARN for creating IAM roles for service accounts"
  value       = module.control_plane.irsa_oidc_provider_arn
}

output "irsa_oidc_issuer_url" {
  description = "IRSA OIDC issuer URL"
  value       = module.control_plane.irsa_oidc_issuer_url
}
