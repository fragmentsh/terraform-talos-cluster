# AWS Node Pools Module for Talos Kubernetes

This module creates ephemeral worker node pools for Talos Kubernetes clusters on AWS.

## Features

- **Map-based node pools**: Define multiple pools with different configurations
- **Auto Scaling Groups**: One ASG per pool with rolling update support
- **Ephemeral instances**: No persistent storage, fully replaceable workers
- **Kubespan enabled**: Auto-discovery across hybrid clusters
- **Multi-AZ support**: Distribute instances across availability zones

## Architecture

Unlike the control plane module which uses 1 ASG per node (for etcd persistence), this module creates 1 ASG per pool with multiple instances. Worker nodes are stateless and can be replaced at any time.

```
┌─────────────────────────────────────────────────┐
│ Node Pool: "default"                            │
│ ┌─────────────────────────────────────────────┐ │
│ │ ASG (desired=3, min=1, max=10)              │ │
│ │   ├─ Instance 0 (us-west-2a)                │ │
│ │   ├─ Instance 1 (us-west-2b)                │ │
│ │   └─ Instance 2 (us-west-2c)                │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Node Pool: "gpu"                                │
│ ┌─────────────────────────────────────────────┐ │
│ │ ASG (desired=2, min=1, max=5)               │ │
│ │   ├─ Instance 0 (us-west-2a)                │ │
│ │   └─ Instance 1 (us-west-2a)                │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "node_pools" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/node-pools/aws"

  cluster_name   = "my-cluster"
  region         = "us-west-2"
  vpc_id         = "vpc-12345678"
  talos_image_id = "ami-0123456789abcdef0"

  kubernetes_version         = "v1.34.2"
  talos_version              = "v1.11.6"
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    default = {
      instance_type    = "m6i.large"
      desired_capacity = 3
      min_size         = 1
      max_size         = 10
      subnet_ids = [
        "subnet-aaaa",
        "subnet-bbbb",
        "subnet-cccc"
      ]
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Multiple Node Pools

```hcl
module "node_pools" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/node-pools/aws"

  cluster_name   = "my-cluster"
  region         = "us-west-2"
  vpc_id         = "vpc-12345678"
  talos_image_id = var.talos_image_id

  kubernetes_version         = var.kubernetes_version
  talos_version              = var.talos_version
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    # General purpose workers
    general = {
      instance_type    = "m6i.large"
      desired_capacity = 3
      min_size         = 1
      max_size         = 10
      subnet_ids       = var.private_subnet_ids
    }

    # GPU workers for ML workloads
    gpu = {
      instance_type    = "g5.xlarge"
      desired_capacity = 2
      min_size         = 0
      max_size         = 5
      subnet_ids       = var.private_subnet_ids

      labels = {
        "workload"         = "gpu"
        "nvidia.com/gpu"   = "true"
      }

      enable_cluster_autoscaler = true

      root_volume = {
        size_gb = 100
        type    = "gp3"
        iops    = 4000
      }

      tags = {
        Workload = "gpu"
      }
    }

    # Batch workloads with taints
    batch = {
      instance_type    = "m6i.xlarge"
      desired_capacity = 5
      min_size         = 0
      max_size         = 20
      subnet_ids       = var.private_subnet_ids

      labels = {
        "workload" = "batch"
      }

      taints = [
        {
          key    = "dedicated"
          value  = "batch"
          effect = "NoSchedule"
        }
      ]

      enable_cluster_autoscaler = true
    }
  }
}
```

### Private Node Pool (No Public IP)

```hcl
node_pools = {
  private = {
    instance_type       = "m6i.large"
    desired_capacity    = 3
    associate_public_ip = false
    subnet_ids          = var.private_subnet_ids
  }
}
```

### Rolling Updates

The module uses `update_launch_template_default_version` to control when instance refresh occurs. This follows the same pattern as the [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) managed node group module.

- When `true` (default for workers): ASG uses `$Latest` launch template version, triggering instance refresh on changes
- When `false`: ASG pins to a specific version, no automatic refresh

```hcl
node_pools = {
  production = {
    instance_type    = "m6i.large"
    desired_capacity = 10
    subnet_ids       = var.subnet_ids

    update_launch_template_default_version = true
  }

  manual-updates = {
    instance_type    = "m6i.large"
    desired_capacity = 5
    subnet_ids       = var.subnet_ids

    update_launch_template_default_version = false
  }
}
```

### Instance Refresh Configuration

Customize rolling update behavior with the `instance_refresh` block:

```hcl
node_pools = {
  default = {
    instance_type    = "m6i.large"
    desired_capacity = 10
    subnet_ids       = var.subnet_ids

    instance_refresh = {
      min_healthy_percentage = 90
      max_healthy_percentage = 150
      instance_warmup        = 120
      skip_matching          = true
      auto_rollback          = true
    }
  }
}
```

| Option | Description | Default |
|--------|-------------|---------|
| `min_healthy_percentage` | Minimum % of instances that must remain healthy | `90` |
| `max_healthy_percentage` | Maximum % of instances (enables surge, 100-200) | `100` |
| `instance_warmup` | Seconds to wait after instance enters InService | `60` |
| `checkpoint_delay` | Seconds to wait between checkpoints | - |
| `checkpoint_percentages` | List of percentages to pause at (e.g., `[25, 50, 75, 100]`) | - |
| `skip_matching` | Skip instances already on latest launch template | `false` |
| `auto_rollback` | Automatically rollback on failure | `false` |
| `scale_in_protected_instances` | Behavior for protected instances: `Refresh`, `Ignore`, `Wait` | `Ignore` |
| `standby_instances` | Behavior for standby instances: `Terminate`, `Ignore`, `Wait` | `Ignore` |
| `alarm_specification.alarms` | CloudWatch alarms that fail the refresh if triggered | - |

### Advanced: Checkpoints with Alarm-Based Rollback

```hcl
node_pools = {
  production = {
    instance_type    = "m6i.large"
    desired_capacity = 100
    subnet_ids       = var.subnet_ids

    instance_refresh = {
      min_healthy_percentage = 90
      max_healthy_percentage = 110
      checkpoint_percentages = [25, 50, 75, 100]
      checkpoint_delay       = 600
      auto_rollback          = true

      alarm_specification = {
        alarms = ["high-error-rate", "high-latency"]
      }
    }
  }
}
```

## Integration with Control Plane

The node pool module requires outputs from the control plane module:

```hcl
module "control_plane" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/control-plane/aws"
  # ... control plane configuration
}

module "node_pools" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/node-pools/aws"

  # Required from control plane
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  # ... rest of configuration
}

# Use outputs for talosctl and health checks
data "talos_client_configuration" "talos" {
  cluster_name         = var.cluster_name
  client_configuration = module.control_plane.talos_client_configuration
  endpoints            = [module.control_plane.kubernetes_api_ip]
  nodes = concat(
    module.control_plane.private_ips,
    module.node_pools.private_ips
  )
}

data "talos_cluster_health" "talos" {
  client_configuration = module.control_plane.talos_client_configuration
  control_plane_nodes  = module.control_plane.private_ips
  worker_nodes         = module.node_pools.private_ips
  endpoints            = [module.control_plane.kubernetes_api_ip]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | The name of the Talos cluster | `string` | n/a | yes |
| region | AWS region for resources | `string` | n/a | yes |
| vpc_id | VPC ID for security groups | `string` | n/a | yes |
| talos_image_id | Talos AMI ID | `string` | n/a | yes |
| kubernetes_api_url | Kubernetes API endpoint URL | `string` | n/a | yes |
| talos_client_configuration | Talos client config from control plane | `any` | n/a | yes |
| talos_machine_secrets | Talos machine secrets from control plane | `any` | n/a | yes |
| node_pools | Map of node pool configurations | `map(object)` | n/a | yes |
| talos_version | Talos OS version | `string` | `"v1.11.6"` | no |
| kubernetes_version | Kubernetes version | `string` | `"v1.34.2"` | no |
| tags | Tags for all resources | `map(string)` | `{}` | no |

### Node Pool Configuration

Each node pool accepts the following configuration:

| Name | Description | Type | Default |
|------|-------------|------|---------|
| instance_type | EC2 instance type | `string` | required |
| desired_capacity | Desired number of instances | `number` | `3` |
| min_size | Minimum number of instances | `number` | `1` |
| max_size | Maximum number of instances | `number` | `10` |
| subnet_ids | List of subnet IDs | `list(string)` | required |
| associate_public_ip | Assign public IP | `bool` | `true` |
| root_volume | Root volume configuration | `object` | see below |
| instance_metadata | IMDSv2 configuration | `object` | see below |
| health_check_type | ASG health check type | `string` | `"EC2"` |
| health_check_grace_period | Health check grace period | `number` | `300` |
| update_launch_template_default_version | Use $Latest version (triggers refresh) | `bool` | `true` |
| instance_refresh | Instance refresh settings | `object` | see below |
| labels | Kubernetes node labels | `map(string)` | `{}` |
| taints | Kubernetes node taints | `list(object)` | `[]` |
| enable_cluster_autoscaler | Enable Cluster Autoscaler ASG tags | `bool` | `false` |
| config_patches | Talos config patches | `list(any)` | `[]` |
| tags | Additional tags | `map(string)` | `{}` |

## Cluster Autoscaler Support

Enable Kubernetes Cluster Autoscaler per node pool by setting `enable_cluster_autoscaler = true`.
The module automatically creates the required ASG tags based on your node labels and taints.

```hcl
node_pools = {
  autoscaled = {
    instance_type    = "m6i.large"
    desired_capacity = 3
    min_size         = 1
    max_size         = 20
    subnet_ids       = var.subnet_ids

    labels = {
      "workload"    = "general"
      "environment" = "production"
    }

    taints = [
      {
        key    = "dedicated"
        value  = "batch"
        effect = "NoSchedule"
      }
    ]

    enable_cluster_autoscaler = true
  }
}
```

**How it works:**

1. **Single source of truth**: Define `labels` and `taints` once in the node pool configuration
2. **Automatic Talos config**: Labels are applied via `kubelet.extraArgs.node-labels`, taints via `kubelet.registerWithTaints`
3. **Automatic CA tags**: ASG tags are automatically derived from your labels and taints

**ASG tags created automatically when `enable_cluster_autoscaler = true`:**

| Tag | Value |
|-----|-------|
| `k8s.io/cluster-autoscaler/enabled` | `true` |
| `k8s.io/cluster-autoscaler/<cluster-name>` | `owned` |
| `k8s.io/cluster-autoscaler/node-template/label/<label-key>` | `<label-value>` |
| `k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type` | `<instance-type>` |
| `k8s.io/cluster-autoscaler/node-template/taint/<taint-key>` | `<value>:<effect>` |

For single-subnet pools, zone topology labels are also added automatically.

**Cluster Autoscaler deployment:**

```bash
--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<cluster-name>
```

## Outputs

| Name | Description |
|------|-------------|
| node_pools | Auto Scaling Groups |
| launch_templates | Launch templates |
| instances | Instance data by pool |
| instances_ips_by_pools | IPs organized by pool |
| external_ips | All public IPs (flat list) |
| private_ips | All private IPs (flat list) |
| security_groups | Security groups by pool |
| iam_roles | IAM roles by pool |
| iam_instance_profiles | Instance profiles by pool |

## Comparison with GCP Module

This module follows the same patterns as the GCP node-pools module:

| Feature | AWS | GCP |
|---------|-----|-----|
| Compute | Auto Scaling Group | Managed Instance Group |
| Network | Security Group | Firewall Rules |
| Identity | IAM Role + Instance Profile | Service Account |
| Scaling | `desired_capacity/min/max` | `target_size` |
| Updates | `instance_refresh` | `update_policy` |
| Output | `external_ips`, `private_ips` | `external_ips`, `private_ips` |
