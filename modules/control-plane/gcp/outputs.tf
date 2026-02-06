output "kubernetes_api_ip" {
  value = google_compute_address.control_plane_api_ip.address
}

output "kubernetes_api_url" {
  value = "https://${google_compute_address.control_plane_api_ip.address}:6443"
}

output "talos_api_ip" {
  value = google_compute_address.control_plane_api_ip.address
}

output "mig" {
  value = module.control_plane_mig
}

output "instance_templates" {
  value = module.control_plane_instance_template
}

output "instances" {
  value = data.google_compute_region_instance_group.control_plane.instances
}

output "external_ips" {
  value = local.control_plane_external_ips
}

output "private_ips" {
  description = "Private IP addresses of control plane instances"
  value       = local.control_plane_private_ips
}

output "talos_machine_secrets" {
  sensitive = true
  value     = talos_machine_secrets.talos.machine_secrets
}

output "talos_client_configuration" {
  sensitive = true
  value     = talos_machine_secrets.talos.client_configuration
}

output "kubeconfig" {
  sensitive = true
  value = {
    raw                  = talos_cluster_kubeconfig.talos.kubeconfig_raw
    client_configuration = talos_cluster_kubeconfig.talos.kubernetes_client_configuration
  }
}
