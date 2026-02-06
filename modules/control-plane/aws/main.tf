data "aws_subnet" "control_plane" {
  for_each = local.control_plane_nodes
  id       = each.value.subnet_id
}

resource "aws_network_interface" "control_plane" {
  for_each = local.control_plane_nodes

  subnet_id       = each.value.subnet_id
  private_ips     = each.value.private_ip != null ? [each.value.private_ip] : null
  security_groups = [aws_security_group.control_plane.id]

  tags = merge(
    local.resource_tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )
}

resource "aws_eip" "control_plane" {
  for_each = {
    for k, v in local.control_plane_nodes : k => v
    if v.enable_eip
  }

  tags = merge(
    local.resource_tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )
}

resource "aws_eip_association" "control_plane" {
  for_each = {
    for k, v in local.control_plane_nodes : k => v
    if v.enable_eip
  }

  allocation_id        = aws_eip.control_plane[each.key].id
  network_interface_id = aws_network_interface.control_plane[each.key].id
}

resource "aws_ebs_volume" "ephemeral" {
  for_each = {
    for k, v in local.control_plane_nodes : k => v
    if v.ephemeral_volume.enabled
  }

  availability_zone = data.aws_subnet.control_plane[each.key].availability_zone
  size              = each.value.ephemeral_volume.size_gb
  type              = each.value.ephemeral_volume.type
  iops              = each.value.ephemeral_volume.iops
  throughput        = each.value.ephemeral_volume.throughput
  encrypted         = each.value.ephemeral_volume.encrypted
  kms_key_id        = each.value.ephemeral_volume.kms_key_id

  tags = merge(
    local.resource_tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-${each.key}-ephemeral"
    }
  )
}

resource "aws_instance" "control_plane" {
  for_each = local.control_plane_nodes

  ami           = var.talos_image_id
  instance_type = each.value.instance_type

  primary_network_interface {
    network_interface_id = aws_network_interface.control_plane[each.key].id
  }

  iam_instance_profile = aws_iam_instance_profile.control_plane.name

  root_block_device {
    volume_size           = each.value.root_volume.size_gb
    volume_type           = each.value.root_volume.type
    iops                  = each.value.root_volume.iops
    throughput            = each.value.root_volume.throughput
    encrypted             = each.value.root_volume.encrypted
    kms_key_id            = each.value.root_volume.kms_key_id
    delete_on_termination = each.value.root_volume.delete_on_termination

    tags = merge(
      local.resource_tags,
      each.value.tags,
      {
        Name = "${var.cluster_name}-${each.key}-root"
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = each.value.instance_metadata_options.http_tokens
    http_put_response_hop_limit = each.value.instance_metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = each.value.instance_metadata_options.instance_metadata_tags
  }

  user_data_base64 = base64encode(data.talos_machine_configuration.control_plane[each.key].machine_configuration)

  tags = merge(
    local.resource_tags,
    local.instance_tags,
    each.value.tags,
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      user_data,
    ]
  }

  depends_on = [
    aws_eip_association.control_plane,
    aws_lb_target_group.k8s_api,
    aws_lb_target_group.talos_api,
  ]
}

resource "aws_volume_attachment" "ephemeral" {
  for_each = {
    for k, v in local.control_plane_nodes : k => v
    if v.ephemeral_volume.enabled
  }

  device_name  = "/dev/sdb"
  volume_id    = aws_ebs_volume.ephemeral[each.key].id
  instance_id  = aws_instance.control_plane[each.key].id
  force_detach = true
}

resource "aws_lb_target_group_attachment" "k8s_api" {
  for_each = local.control_plane_nodes

  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = aws_instance.control_plane[each.key].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "talos_api" {
  for_each = local.control_plane_nodes

  target_group_arn = aws_lb_target_group.talos_api.arn
  target_id        = aws_instance.control_plane[each.key].id
  port             = 50000
}
