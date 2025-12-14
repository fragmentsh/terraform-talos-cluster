output "network" {
  value = module.network
}

output "control_plane" {
  value     = module.control_plane
  sensitive = true
}

output "kubeconfig" {
  sensitive = true
  value     = module.control_plane.kubeconfig.raw
}

output "control_plane_api_url" {
  value = module.control_plane.kubernetes_api_url
}

output "talosconfig" {
  sensitive = true
  value     = data.talos_client_configuration.talos.talos_config
}
