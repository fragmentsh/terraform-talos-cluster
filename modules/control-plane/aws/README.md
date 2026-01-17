<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.10.0-beta.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0-beta.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.asg_failed_launches](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_duration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.nlb_unhealthy_targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ebs_volume.etcd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_iam_instance_profile.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.attach_volume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.kubernetes_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.kubernetes_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [talos_cluster_kubeconfig.talos](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.talos](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.talos](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/resources/machine_secrets) | resource |
| [aws_ami.talos](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_instances.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instances) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for control plane distribution. Nodes will be distributed across these zones using round-robin. | `list(string)` | n/a | yes |
| <a name="input_cloudwatch"></a> [cloudwatch](#input\_cloudwatch) | CloudWatch monitoring and alerting configuration. | <pre>object({<br/>    create_alarms = optional(bool, true)<br/>    alarm_sns_topic_arn = optional(string)<br/>    lambda_error_threshold = optional(number, 0)<br/>    lambda_duration_threshold = optional(number, 240000)<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Configuration for the control plane instances. | <pre>object({<br/>    instance_type = string<br/>    count = number<br/>    root_volume = optional(object({...}), {})<br/>    etcd_volume = optional(object({...}), {})<br/>    instance_metadata = optional(object({...}), {})<br/>    wait_for_capacity_timeout = optional(string, "10m")<br/>    default_cooldown = optional(number, 300)<br/>    health_check_grace_period = optional(number, 300)<br/>    health_check_type = optional(string, "ELB")<br/>    protect_from_scale_in = optional(bool, true)<br/>    associate_public_ip = optional(bool, true)<br/>    tags = optional(map(string), {})<br/>    config_patches = optional(list(any), [])<br/>  })</pre> | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy on the Talos control plane. | `string` | `"v1.34.2"` | no |
| <a name="input_lambda"></a> [lambda](#input\_lambda) | Lambda function configuration for volume attachment. | <pre>object({<br/>    timeout = optional(number, 300)<br/>    memory_size = optional(number, 256)<br/>    runtime = optional(string, "python3.12")<br/>    log_retention = optional(number, 7)<br/>    max_retry_attempts = optional(number, 5)<br/>    retry_delay_base = optional(number, 2)<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_load_balancer"></a> [load\_balancer](#input\_load\_balancer) | Network Load Balancer configuration for Kubernetes API. | <pre>object({<br/>    internal = optional(bool, false)<br/>    enable_cross_zone_load_balancing = optional(bool, true)<br/>    enable_deletion_protection = optional(bool, true)<br/>    deregistration_delay = optional(number, 30)<br/>    health_check = optional(object({...}), {})<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where resources will be created. | `string` | n/a | yes |
| <a name="input_security_group"></a> [security\_group](#input\_security\_group) | Security group configuration for control plane instances. | <pre>object({<br/>    additional_ingress_rules = optional(list(object({...})), [])<br/>    additional_egress_rules = optional(list(object({...})), [])<br/>    api_ingress_cidr_blocks = optional(list(string), ["0.0.0.0/0"])<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Map of availability zone to subnet ID for control plane placement. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_talos_image"></a> [talos\_image](#input\_talos\_image) | Talos OS AMI configuration. Either specify 'id' directly, or use 'owner' and 'name' for AMI lookup. | <pre>object({<br/>    id = optional(string)<br/>    owner = optional(string, "540036508848")<br/>    name = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use for the control plane instances. | `string` | `"v1.11.6"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where control plane will be deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asgs"></a> [asgs](#output\_asgs) | Auto Scaling Group information |
| <a name="output_etcd_volumes"></a> [etcd\_volumes](#output\_etcd\_volumes) | EBS volumes for etcd data |
| <a name="output_external_ips"></a> [external\_ips](#output\_external\_ips) | External IP addresses of control plane instances |
| <a name="output_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#output\_iam\_instance\_profile\_name) | IAM instance profile name for control plane instances |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN for control plane instances |
| <a name="output_instance_templates"></a> [instance\_templates](#output\_instance\_templates) | Launch template information |
| <a name="output_instances"></a> [instances](#output\_instances) | Control plane instance information |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes kubeconfig for kubectl access |
| <a name="output_kubernetes_api_ip"></a> [kubernetes\_api\_ip](#output\_kubernetes\_api\_ip) | Kubernetes API endpoint IP address (NLB DNS name) |
| <a name="output_kubernetes_api_url"></a> [kubernetes\_api\_url](#output\_kubernetes\_api\_url) | Kubernetes API endpoint URL |
| <a name="output_lambda_function"></a> [lambda\_function](#output\_lambda\_function) | Lambda function for volume attachment |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | Network Load Balancer information |
| <a name="output_private_ips"></a> [private\_ips](#output\_private\_ips) | Private IP addresses of control plane instances |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for control plane instances |
| <a name="output_talos_ami"></a> [talos\_ami](#output\_talos\_ami) | Talos AMI used for control plane instances |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Talos client configuration for talosctl |
| <a name="output_talos_machine_secrets"></a> [talos\_machine\_secrets](#output\_talos\_machine\_secrets) | Talos machine secrets (sensitive) |
<!-- END_TF_DOCS -->

## Architecture

This module implements a production-ready Talos Kubernetes control plane on AWS with persistent etcd storage.

### Key Design Decisions

1. **1 ASG per Control Plane Node**: Following the Kops-proven pattern, each control plane node runs in its own ASG. This provides:
   - Deterministic volume-to-instance mapping
   - Independent lifecycle management per node
   - Predictable etcd member identity across replacements

2. **Separate EBS Volumes for etcd**: Each control plane node has a dedicated EBS volume for etcd data that persists across instance replacements.

3. **Lambda + Lifecycle Hooks**: A Lambda function triggered by ASG lifecycle hooks handles volume attachment before instances boot, ensuring:
   - Reliable volume attachment (not dependent on instance user-data timing)
   - Proper error handling and retries
   - Clean lifecycle completion signaling

4. **Network Load Balancer**: Provides a stable Kubernetes API endpoint with:
   - TCP passthrough (no TLS termination)
   - Cross-zone load balancing
   - Health checking on port 6443

### Node Distribution

Control plane nodes are distributed across availability zones. By default, nodes use round-robin distribution based on their index:

```
nodes={"0","1","2"}, azs=[a,b,c] -> cp-0:a, cp-1:b, cp-2:c
nodes={"0".."4"},    azs=[a,b,c] -> cp-0:a, cp-1:b, cp-2:c, cp-3:a, cp-4:b
```

You can also explicitly set the availability zone per node for full control.

## Usage

### Basic Example

```hcl
module "control_plane" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "my-cluster"
  region             = "us-west-2"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_id             = "vpc-12345678"

  subnet_ids = {
    "us-west-2a" = "subnet-aaaa"
    "us-west-2b" = "subnet-bbbb"
    "us-west-2c" = "subnet-cccc"
  }

  control_plane = {
    instance_type = "m6i.large"

    nodes = {
      "0" = {}
      "1" = {}
      "2" = {}
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### 5-Node Control Plane

```hcl
module "control_plane" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "ha-cluster"
  region             = "eu-west-1"
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  vpc_id             = "vpc-87654321"

  subnet_ids = {
    "eu-west-1a" = "subnet-1111"
    "eu-west-1b" = "subnet-2222"
    "eu-west-1c" = "subnet-3333"
  }

  control_plane = {
    instance_type = "m6i.xlarge"

    nodes = {
      "0" = {}
      "1" = {}
      "2" = {}
      "3" = {}
      "4" = {}
    }

    root_volume = {
      size_gb = 100
      type    = "gp3"
      iops    = 4000
    }

    etcd_volume = {
      size_gb    = 50
      type       = "gp3"
      iops       = 6000
      throughput = 250
    }
  }

  load_balancer = {
    internal                   = true
    enable_deletion_protection = true
  }
}
```

### Private Control Plane

```hcl
module "control_plane" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "private-cluster"
  region             = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  vpc_id             = "vpc-private123"

  subnet_ids = {
    "us-east-1a" = "subnet-priv-a"
    "us-east-1b" = "subnet-priv-b"
    "us-east-1c" = "subnet-priv-c"
  }

  control_plane = {
    instance_type       = "m6i.large"
    associate_public_ip = false

    nodes = {
      "0" = {}
      "1" = {}
      "2" = {}
    }
  }

  load_balancer = {
    internal = true
  }

  security_group = {
    api_ingress_cidr_blocks = ["10.0.0.0/8"]
  }
}
```

### Per-Node Configuration

Each node can have individual overrides for instance type, availability zone, config patches, and tags:

```hcl
control_plane = {
  instance_type = "m6i.large"

  nodes = {
    "0" = {
      availability_zone = "us-west-2a"
      instance_type     = "m6i.xlarge"
    }
    "1" = {
      availability_zone = "us-west-2b"
    }
    "2" = {
      availability_zone = "us-west-2c"
      config_patches = [
        yamlencode({
          machine = {
            kubelet = {
              extraArgs = {
                node-labels = "special=true"
              }
            }
          }
        })
      ]
    }
  }
}
```

## Rolling Updates

The module supports controlled rolling updates using the `update_launch_template_default_version` flag per node. This follows the same pattern as the [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) managed node group module.

- When `true`: ASG uses `$Latest` launch template version, triggering instance refresh
- When `false` (default): ASG pins to a specific version, no refresh occurs

### Rolling Update Workflow

When changing instance type or other launch template parameters:

**Step 1**: Update node 0 first:

```hcl
control_plane = {
  instance_type = "m6i.xlarge"

  nodes = {
    "0" = { update_launch_template_default_version = true }
    "1" = {}
    "2" = {}
  }
}
```

Run `terraform apply` - only node 0 will be replaced.

**Step 2**: After node 0 is healthy, update node 1:

```hcl
control_plane = {
  instance_type = "m6i.xlarge"

  nodes = {
    "0" = { update_launch_template_default_version = true }
    "1" = { update_launch_template_default_version = true }
    "2" = {}
  }
}
```

Run `terraform apply` - only node 1 will be replaced.

**Step 3**: After node 1 is healthy, update node 2:

```hcl
control_plane = {
  instance_type = "m6i.xlarge"

  nodes = {
    "0" = { update_launch_template_default_version = true }
    "1" = { update_launch_template_default_version = true }
    "2" = { update_launch_template_default_version = true }
  }
}
```

Run `terraform apply` - node 2 will be replaced.

This ensures etcd quorum is maintained throughout the update process.

### Why This Design?

- **Safe by default**: `update_launch_template_default_version = false` means no unexpected updates
- **Explicit control**: You declare which nodes should update
- **GitOps friendly**: Easy to track in version control (one PR per node update)
- **Industry standard**: Matches EKS module pattern familiar to AWS users

## etcd Persistence

The module creates separate EBS volumes for etcd data. When an instance is replaced:

1. ASG lifecycle hook pauses instance launch
2. Lambda function identifies the correct etcd volume for the slot
3. Volume is attached to the new instance (appears as `/dev/nvme1n1` on Nitro instances)
4. Talos mounts the volume at `/var/lib/etcd`
5. Lifecycle hook completes, instance continues booting

This ensures etcd data survives instance replacements, maintaining cluster state and preventing data loss.

**Note**: This module requires Nitro-based instances (m5, m6i, c5, c6i, etc.) due to NVMe device naming.

## Scaling Considerations

- **Odd numbers only**: etcd requires odd quorum sizes (1, 3, 5, 7)
- **Cross-AZ distribution**: Nodes automatically spread across provided AZs
- **Add capacity**: Increase `control_plane.count` and apply
- **Remove capacity**: Decrease `control_plane.count` (volumes persist for potential scale-up)

## Monitoring

When `cloudwatch.create_alarms = true` (default), the module creates CloudWatch alarms for:

- Lambda function errors
- Lambda function duration (approaching timeout)
- ASG failed launches
- NLB unhealthy targets

Configure SNS notifications via `cloudwatch.alarm_sns_topic_arn`.
