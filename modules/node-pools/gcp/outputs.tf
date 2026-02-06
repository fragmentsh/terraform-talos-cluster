output "migs" {
  value = module.node_pool_mig
}

output "instance_templates" {
  value = module.node_pool_instance_template
}

output "instances" {
  value = data.google_compute_region_instance_group.node_pool
}

output "instances_ips_by_pools" {
  value = local.node_pools_instances_ips_by_pool
}

output "external_ips" {
  value = local.node_pools_external_ips
}

output "private_ips" {
  value = local.node_pools_private_ips
}
