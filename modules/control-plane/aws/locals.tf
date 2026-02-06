locals {
  control_plane_count = length(var.control_plane.nodes)

  control_plane_nodes_keys = sort(keys(var.control_plane.nodes))

  control_plane_nodes = {
    for k, v in var.control_plane.nodes :
    k => {
      instance_type = coalesce(v.instance_type, var.control_plane.instance_type)
      enable_eip    = coalesce(v.enable_eip, true)
      private_ip    = v.private_ip

      config_patches = concat(
        var.control_plane.config_patches,
        coalesce(v.config_patches, [])
      )

      tags = merge(var.control_plane.tags, coalesce(v.tags, {}))

      # Use coalesce per field to properly inherit global defaults
      # merge() doesn't work because optional() fields without defaults become null,
      # and merge() overwrites non-null values with null values from the second object
      root_volume = {
        size_gb               = coalesce(v.root_volume.size_gb, var.control_plane.root_volume.size_gb)
        type                  = coalesce(v.root_volume.type, var.control_plane.root_volume.type)
        iops                  = coalesce(v.root_volume.iops, var.control_plane.root_volume.iops)
        throughput            = coalesce(v.root_volume.throughput, var.control_plane.root_volume.throughput)
        encrypted             = coalesce(v.root_volume.encrypted, var.control_plane.root_volume.encrypted)
        kms_key_id            = try(coalesce(v.root_volume.kms_key_id, var.control_plane.root_volume.kms_key_id), null)
        delete_on_termination = coalesce(v.root_volume.delete_on_termination, var.control_plane.root_volume.delete_on_termination)
      }

      ephemeral_volume = {
        enabled    = coalesce(v.ephemeral_volume.enabled, var.control_plane.ephemeral_volume.enabled)
        size_gb    = coalesce(v.ephemeral_volume.size_gb, var.control_plane.ephemeral_volume.size_gb)
        type       = coalesce(v.ephemeral_volume.type, var.control_plane.ephemeral_volume.type)
        iops       = coalesce(v.ephemeral_volume.iops, var.control_plane.ephemeral_volume.iops)
        throughput = coalesce(v.ephemeral_volume.throughput, var.control_plane.ephemeral_volume.throughput)
        encrypted  = coalesce(v.ephemeral_volume.encrypted, var.control_plane.ephemeral_volume.encrypted)
        kms_key_id = try(coalesce(v.ephemeral_volume.kms_key_id, var.control_plane.ephemeral_volume.kms_key_id), null)
      }

      instance_metadata_options = {
        http_tokens                 = coalesce(v.instance_metadata_options.http_tokens, var.control_plane.instance_metadata_options.http_tokens)
        http_put_response_hop_limit = coalesce(v.instance_metadata_options.http_put_response_hop_limit, var.control_plane.instance_metadata_options.http_put_response_hop_limit)
        instance_metadata_tags      = coalesce(v.instance_metadata_options.instance_metadata_tags, var.control_plane.instance_metadata_options.instance_metadata_tags)
      }

      subnet_id = coalesce(v.subnet_id, var.control_plane.subnet_ids[index(local.control_plane_nodes_keys, k) % length(var.control_plane.subnet_ids)])
    }
  }

  nlb_subnet_ids = [for k in local.control_plane_nodes_keys : local.control_plane_nodes[k].subnet_id]

  resource_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      KubernetesCluster                           = var.cluster_name
    }
  )

  instance_tags = merge(
    var.tags,
    {
      KubernetesCluster                           = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}
