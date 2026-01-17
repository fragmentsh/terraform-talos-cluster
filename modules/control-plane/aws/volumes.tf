resource "aws_ebs_volume" "ephemeral" {
  for_each = local.control_plane_nodes

  availability_zone = each.value.az
  size              = local.ephemeral_volume_config.size_gb
  type              = local.ephemeral_volume_config.type
  iops              = local.ephemeral_volume_config.type == "gp3" || local.ephemeral_volume_config.type == "io1" || local.ephemeral_volume_config.type == "io2" ? local.ephemeral_volume_config.iops : null
  throughput        = local.ephemeral_volume_config.type == "gp3" ? local.ephemeral_volume_config.throughput : null
  encrypted         = local.ephemeral_volume_config.encrypted
  kms_key_id        = local.ephemeral_volume_config.kms_key_id

  tags = merge(
    local.volume_tags,
    var.control_plane.tags,
    {
      Name       = "${var.cluster_name}-ephemeral-${each.key}"
      Slot       = tostring(each.value.slot)
      VolumeType = "ephemeral"
    }
  )

}
