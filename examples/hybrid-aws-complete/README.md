# AWS Hybrid Talos Cluster Example

This example demonstrates how to deploy a production-ready Talos Kubernetes cluster on AWS with:

- **Control Plane**: 3-node HA control plane with persistent etcd storage
- **Multi-Region VPC**: Primary and secondary VPCs for hybrid node pools
- **Network Load Balancer**: Stable Kubernetes API endpoint
- **Kubespan**: Secure cross-region connectivity

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AWS Account                                    │
├─────────────────────────────────┬───────────────────────────────────────┤
│       Primary Region            │       Secondary Region                 │
│       (eu-west-1)               │       (eu-west-3)                      │
├─────────────────────────────────┼───────────────────────────────────────┤
│                                 │                                        │
│  ┌───────────────────────────┐  │  ┌───────────────────────────────────┐│
│  │        VPC Primary        │  │  │        VPC Secondary              ││
│  │      10.42.0.0/16         │  │  │       10.45.0.0/16                ││
│  │                           │  │  │                                   ││
│  │  ┌─────────────────────┐  │  │  │  ┌───────────────────────────┐   ││
│  │  │   Public Subnets    │  │  │  │  │    Public Subnets         │   ││
│  │  │  10.42.101-103.0/24 │  │  │  │  │   10.45.101-103.0/24      │   ││
│  │  │                     │  │  │  │  │                           │   ││
│  │  │  ┌───┐ ┌───┐ ┌───┐  │  │  │  │  │   ┌───────────────────┐   │   ││
│  │  │  │CP0│ │CP1│ │CP2│  │  │  │  │   │   │  Worker Nodes     │   │   ││
│  │  │  └─┬─┘ └─┬─┘ └─┬─┘  │  │  │  │   │   │  (via Kubespan)   │   │   ││
│  │  │    │     │     │    │  │  │  │   │   └───────────────────┘   │   ││
│  │  │    └─────┼─────┘    │  │  │  │  └───────────────────────────┘   ││
│  │  │          │          │  │  │  │                                   ││
│  │  │    ┌─────┴─────┐    │  │  │  │  ┌───────────────────────────┐   ││
│  │  │    │    NLB    │    │  │  │  │  │    Private Subnets        │   ││
│  │  │    │ K8s API   │    │  │  │  │  │   10.45.1-3.0/24          │   ││
│  │  │    └───────────┘    │  │  │  │  └───────────────────────────┘   ││
│  │  └─────────────────────┘  │  │  │                                   ││
│  │                           │  │  └───────────────────────────────────┘│
│  │  ┌─────────────────────┐  │  │                                        │
│  │  │   Private Subnets   │  │  │                                        │
│  │  │  10.42.1-3.0/24     │  │  │                                        │
│  │  └─────────────────────┘  │  │                                        │
│  │                           │  │                                        │
│  └───────────────────────────┘  │                                        │
│                                 │                                        │
└─────────────────────────────────┴────────────────────────────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.7
- `talosctl` CLI installed (for cluster management)
- `kubectl` installed (for Kubernetes access)

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the plan

```bash
terraform plan
```

### 3. Apply the configuration

```bash
terraform apply
```

### 4. Access the cluster

Export the kubeconfig:

```bash
terraform output -raw kubeconfig > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

Export the talosconfig:

```bash
terraform output -raw talosconfig > talosconfig
export TALOSCONFIG=$(pwd)/talosconfig
talosctl health
```

### 5. Install CNI (Cilium)

After the cluster is healthy, install Cilium:

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445
```

### 6. Verify the cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## Customization

### Control Plane Size

Modify the `control_plane.count` variable for different HA configurations:

```hcl
control_plane = {
  instance_type = "m6i.xlarge"  # Larger instance
  count         = 5              # 5-node control plane

  etcd_volume = {
    size_gb    = 50   # Larger etcd volume
    type       = "gp3"
    iops       = 6000  # Higher IOPS
    throughput = 250
  }
}
```

### Private Control Plane

For private deployments (no public IPs):

```hcl
control_plane = {
  instance_type       = "m6i.large"
  count               = 3
  associate_public_ip = false  # No public IPs
}

load_balancer = {
  internal = true  # Internal NLB
}

# Use private subnets instead
subnet_ids = {
  for i, az in slice(data.aws_availability_zones.primary.names, 0, 3) :
  az => module.vpc_primary.private_subnets[i]
}
```

### Custom Talos Configuration

Add custom Talos machine configuration patches:

```hcl
control_plane = {
  instance_type = "m6i.large"
  count         = 3

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "custom-hostname"
        }
      }
    })
  ]
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| region | Primary AWS region | string | eu-west-1 |
| region_secondary | Secondary AWS region | string | eu-west-3 |
| cluster_name | Name of the Talos cluster | string | talos-demo-cluster |
| kubernetes_version | Kubernetes version | string | v1.34.2 |
| talos_version | Talos OS version | string | v1.11.6 |

## Outputs

| Name | Description |
|------|-------------|
| control_plane_api_url | Kubernetes API endpoint URL |
| control_plane_external_ips | Control plane instance IPs |
| kubeconfig | Kubernetes kubeconfig (sensitive) |
| talosconfig | Talos client configuration (sensitive) |
| load_balancer | NLB information |
| etcd_volumes | etcd EBS volume information |

## Cleanup

```bash
terraform destroy
```

**Note**: If `enable_deletion_protection` is set to `true` on the NLB, you'll need to disable it first:

```bash
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn <nlb-arn> \
  --attributes Key=deletion_protection.enabled,Value=false
```

## Cost Considerations

This example creates the following billable resources:

- 3x m6i.large EC2 instances (control plane)
- 3x 50GB gp3 EBS volumes (root)
- 3x 20GB gp3 EBS volumes (etcd)
- 1x Network Load Balancer
- 2x NAT Gateways (one per VPC)
- Lambda function (minimal cost)
- CloudWatch logs and alarms

Estimated cost: ~$300-400/month (varies by region and usage)

For cost optimization:
- Use Spot instances for worker nodes
- Use smaller instances for dev/test
- Reduce to single NAT gateway
- Disable CloudWatch alarms in non-production
