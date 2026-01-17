output "vpc_primary" {
  description = "Primary VPC information"
  value = {
    vpc_id          = module.vpc_primary.vpc_id
    public_subnets  = module.vpc_primary.public_subnets
    private_subnets = module.vpc_primary.private_subnets
  }
}

output "vpc_secondary" {
  description = "Secondary VPC information"
  value = {
    vpc_id          = module.vpc_secondary.vpc_id
    public_subnets  = module.vpc_secondary.public_subnets
    private_subnets = module.vpc_secondary.private_subnets
  }
}

output "control_plane" {
  description = "Control plane module outputs"
  value       = module.control_plane
  sensitive   = true
}

output "control_plane_api_url" {
  description = "Kubernetes API endpoint URL"
  value       = module.control_plane.kubernetes_api_url
}

output "control_plane_external_ips" {
  description = "Control plane instance external IPs"
  value       = module.control_plane.external_ips
}

output "kubeconfig" {
  description = "Kubernetes kubeconfig for kubectl access"
  sensitive   = true
  value       = talos_cluster_kubeconfig.talos.kubeconfig_raw
}

output "kubernetes_client_configuration" {
  description = "Kubernetes client configuration for kubectl"
  value       = talos_cluster_kubeconfig.talos.kubernetes_client_configuration
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration for talosctl"
  sensitive   = true
  value       = data.talos_client_configuration.talos.talos_config
}

output "load_balancer" {
  description = "Network Load Balancer information"
  value       = module.control_plane.load_balancer
}

output "node_pools_primary" {
  description = "Primary region node pool information"
  value = {
    external_ips = module.node_pools_primary.external_ips
    private_ips  = module.node_pools_primary.private_ips
  }
}

output "node_pools_secondary" {
  description = "Secondary region node pool information"
  value = {
    external_ips = module.node_pools_secondary.external_ips
    private_ips  = module.node_pools_secondary.private_ips
  }
}
