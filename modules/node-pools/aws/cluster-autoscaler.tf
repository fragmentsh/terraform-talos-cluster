# Cluster Autoscaler ASG Tags (computed as locals, applied inline in ASG)
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md

locals {
  taint_effects = {
    "NoSchedule"       = "NoSchedule"
    "NoExecute"        = "NoExecute"
    "PreferNoSchedule" = "PreferNoSchedule"
  }

  ca_tags_defaults = {
    for pool_key, pool_value in var.node_pools : pool_key => pool_value.enable_cluster_autoscaler ? {
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    } : {}
  }

  ca_tags_labels = {
    for pool_key, pool_value in var.node_pools : pool_key => pool_value.enable_cluster_autoscaler ? {
      for label_key, label_value in pool_value.labels :
      "k8s.io/cluster-autoscaler/node-template/label/${label_key}" => label_value
    } : {}
  }

  ca_tags_taints = {
    for pool_key, pool_value in var.node_pools : pool_key => pool_value.enable_cluster_autoscaler ? {
      for taint in pool_value.taints :
      "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}" => "${taint.value}:${local.taint_effects[taint.effect]}"
    } : {}
  }

  ca_tags_implicit = {
    for pool_key, pool_value in var.node_pools : pool_key => pool_value.enable_cluster_autoscaler ? merge(
      {
        "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type" = pool_value.instance_type
      },
      length(pool_value.subnet_ids) == 1 ? {
        "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"   = data.aws_subnet.node_pool_subnet[pool_key].availability_zone
        "k8s.io/cluster-autoscaler/node-template/label/topology.ebs.csi.aws.com/zone" = data.aws_subnet.node_pool_subnet[pool_key].availability_zone
      } : {}
    ) : {}
  }

  ca_tags_all = {
    for pool_key in keys(var.node_pools) : pool_key => merge(
      local.ca_tags_defaults[pool_key],
      local.ca_tags_labels[pool_key],
      local.ca_tags_taints[pool_key],
      local.ca_tags_implicit[pool_key]
    )
  }
}

data "aws_subnet" "node_pool_subnet" {
  for_each = {
    for pool_key, pool_value in var.node_pools :
    pool_key => pool_value
    if pool_value.enable_cluster_autoscaler && length(pool_value.subnet_ids) == 1
  }

  id = each.value.subnet_ids[0]
}
