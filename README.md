# Terraform Talos Cluster

[![Pre-Commit](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/pre-commit.yml)
[![Release](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/release.yml/badge.svg)](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/release.yml)

Production-ready Terraform modules for deploying **hybrid [Talos](https://www.talos.dev/) Kubernetes clusters** across multiple cloud providers and regions.

## Why This Project?

Running Kubernetes in production often requires:
- **Multi-region resilience** - Distribute workloads across regions for high availability
- **Multi-cloud flexibility** - Avoid vendor lock-in and leverage best-of-breed services
- **Cost optimization** - Place workloads where they're cheapest or most performant
- **Security by default** - Immutable OS, encrypted communications, minimal attack surface

This project solves these challenges by providing opinionated, battle-tested Terraform modules that deploy Talos-based Kubernetes clusters with **Kubespan mesh networking**, enabling seamless hybrid deployments.

## Architecture

```
                            ┌─────────────────────────────────────────────────────────┐
                            │                    Control Plane                         │
                            │              (AWS/GCP - Single Region)                   │
                            │  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
                            │  │  CP-0   │  │  CP-1   │  │  CP-2   │                  │
                            │  │ (etcd)  │  │ (etcd)  │  │ (etcd)  │                  │
                            │  └────┬────┘  └────┬────┘  └────┬────┘                  │
                            │       │            │            │                        │
                            │       └────────────┼────────────┘                        │
                            │                    │                                     │
                            │              ┌─────┴─────┐                               │
                            │              │    NLB    │ ◄── Kubernetes API (6443)     │
                            │              └─────┬─────┘     Talos API (50000)         │
                            └────────────────────┼────────────────────────────────────┘
                                                 │
                     ┌───────────────────────────┼───────────────────────────┐
                     │                           │                           │
            ┌────────┴────────┐        ┌────────┴────────┐        ┌────────┴────────┐
            │   Kubespan      │        │   Kubespan      │        │   Kubespan      │
            │  (WireGuard)    │        │  (WireGuard)    │        │  (WireGuard)    │
            └────────┬────────┘        └────────┬────────┘        └────────┬────────┘
                     │                          │                          │
    ┌────────────────┴────────────────┐  ┌─────┴─────┐  ┌─────────────────┴─────────────────┐
    │     Node Pool: AWS us-west-2    │  │  AWS      │  │    Node Pool: GCP europe-west1    │
    │  ┌────────┐ ┌────────┐ ┌──────┐ │  │  eu-west  │  │  ┌────────┐ ┌────────┐ ┌───────┐ │
    │  │Worker 0│ │Worker 1│ │  ... │ │  │  ┌────┐   │  │  │Worker 0│ │Worker 1│ │  ...  │ │
    │  └────────┘ └────────┘ └──────┘ │  │  │ W0 │   │  │  └────────┘ └────────┘ └───────┘ │
    └─────────────────────────────────┘  │  └────┘   │  └──────────────────────────────────┘
                                         └───────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Decoupled control plane** | Control plane and node pools are separate modules, similar to managed Kubernetes. This allows node pools in different regions/clouds while maintaining a stable control plane. |
| **Kubespan mesh networking** | Built-in WireGuard-based mesh network connects all nodes regardless of network topology. No VPN or peering required between clouds. |
| **Immutable infrastructure** | Talos OS is API-managed, read-only, and minimal. No SSH, no shell, no package manager = reduced attack surface. |
| **CNI: BYO (Cilium recommended)** | CNI is disabled by default. We recommend [Cilium](https://cilium.io/) for its eBPF-based networking, but any CNI works. |
| **Per-node control plane (AWS)** | Each control plane node has its own resources (ENI, EIP, EBS) for stable etcd identity across replacements. |

## Supported Cloud Providers

| Provider | Control Plane | Node Pools | Status |
|----------|---------------|------------|--------|
| **AWS** | ✅ | ✅ | Production-ready |
| **GCP** | ✅ | ✅ | Production-ready |
| Azure | ❌ | ❌ | Contributions welcome |
| Bare Metal | ❌ | ❌ | Contributions welcome |

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.5.7 | Infrastructure provisioning |
| [talosctl](https://www.talos.dev/latest/introduction/getting-started/#talosctl) | >= 1.6.0 | Talos cluster management |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Kubernetes management |
| [OpenSSL](https://www.openssl.org/) | Any | Required for IRSA key generation (AWS) |

### Cloud Provider Setup

<details>
<summary><strong>AWS</strong></summary>

```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-west-2"
```

**Required IAM Permissions:**
- EC2 (instances, EBS, EIP, ENI, security groups)
- ELB (NLB, target groups)
- IAM (roles, policies, OIDC provider for IRSA)
- S3 (IRSA OIDC discovery bucket)
- CloudWatch (optional, for alarms)

</details>

<details>
<summary><strong>GCP</strong></summary>

```bash
# Authenticate with GCP
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

**Required APIs:**
- Compute Engine API
- Cloud Resource Manager API

**Required IAM Roles:**
- `roles/compute.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/storage.admin` (for factory module)

</details>

## Quick Start

### Option 1: Use the Example (Recommended for First-Time Users)

```bash
# Clone the repository
git clone https://github.com/fragmentsh/terraform-talos-cluster.git
cd terraform-talos-cluster/examples/hybrid-aws

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the cluster
terraform apply

# Get kubeconfig
terraform output -raw kubeconfig > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster
kubectl get nodes
```

### Option 2: Use as Terraform Module

```hcl
# Get the official Talos AMI
module "talos_ami" {
  source        = "github.com/fragmentsh/terraform-talos-cluster//modules/cloud-images/aws"
  talos_version = "v1.12.2"
  region        = "us-west-2"
}

# Deploy control plane
module "control_plane" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "my-cluster"
  vpc_id             = module.vpc.vpc_id
  talos_image_id     = module.talos_ami.ami_id
  kubernetes_version = "v1.35.0"
  talos_version      = "v1.12.2"

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = module.vpc.public_subnets

    nodes = {
      "cp-0" = {}
      "cp-1" = {}
      "cp-2" = {}
    }
  }

  irsa = {
    enabled = true  # Enable IRSA for AWS IAM integration
  }
}

# Deploy worker node pools
module "node_pools" {
  source = "github.com/fragmentsh/terraform-talos-cluster//modules/node-pools/aws"

  cluster_name               = "my-cluster"
  vpc_id                     = module.vpc.vpc_id
  talos_image_id             = module.talos_ami.ami_id
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    general = {
      instance_type    = "m6i.large"
      desired_capacity = 3
      min_size         = 1
      max_size         = 10
      subnet_ids       = module.vpc.private_subnets
    }
  }
}

# Output kubeconfig
output "kubeconfig" {
  value     = module.control_plane.kubeconfig
  sensitive = true
}
```

## Modules

### Control Plane Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [control-plane/aws](./modules/control-plane/aws) | AWS control plane with NLB, IRSA support, and CloudWatch monitoring | [README](./modules/control-plane/aws/README.md) |
| [control-plane/gcp](./modules/control-plane/gcp) | GCP control plane with regional MIG and external load balancer | [README](./modules/control-plane/gcp/README.md) |

### Node Pool Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [node-pools/aws](./modules/node-pools/aws) | AWS worker nodes with ASG, rolling updates, and Cluster Autoscaler support | [README](./modules/node-pools/aws/README.md) |
| [node-pools/gcp](./modules/node-pools/gcp) | GCP worker nodes with regional MIG | [README](./modules/node-pools/gcp/README.md) |

### Utility Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [cloud-images/aws](./modules/cloud-images/aws) | Lookup official Talos AMI IDs by version and region | [README](./modules/cloud-images/aws/README.md) |
| [factory](./modules/factory) | Build and upload custom Talos images with extensions | [README](./modules/factory/README.md) |

## Examples

| Example | Description |
|---------|-------------|
| [hybrid-aws](./examples/hybrid-aws) | Complete AWS deployment with control plane, node pools, Cilium CNI, and common add-ons |
| [hybrid-gcp](./examples/hybrid-gcp) | Complete GCP deployment with multi-region node pools |

## Post-Deployment

### Install a CNI (Required)

The cluster ships without a CNI. Install Cilium (recommended):

```bash
# Using Cilium CLI
cilium install --set kubeProxyReplacement=true

# Or using Helm
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${KUBERNETES_API_IP}" \
  --set k8sServicePort=6443
```

### Verify Cluster Health

```bash
# Check Talos cluster health
talosctl --talosconfig talosconfig health

# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system
```

### Access Talos API

```bash
# Generate talosconfig
terraform output -raw talosconfig > talosconfig

# List nodes
talosctl --talosconfig talosconfig get members

# View logs
talosctl --talosconfig talosconfig logs kubelet

# Dashboard (interactive)
talosctl --talosconfig talosconfig dashboard
```

## Upgrading

### Upgrade Talos OS

```bash
# Upgrade control plane nodes (one at a time)
talosctl --talosconfig talosconfig upgrade \
  --nodes <node-ip> \
  --image ghcr.io/siderolabs/installer:v1.12.2

# Upgrade worker nodes
talosctl --talosconfig talosconfig upgrade \
  --nodes <worker-ip> \
  --image ghcr.io/siderolabs/installer:v1.12.2
```

### Upgrade Kubernetes

```bash
talosctl --talosconfig talosconfig upgrade-k8s \
  --to 1.35.0
```

## Security Considerations

| Feature | Implementation |
|---------|----------------|
| **No SSH** | Talos has no SSH daemon. All management via Talos API. |
| **Mutual TLS** | All Talos API calls use client certificates |
| **Encrypted at rest** | Enable EBS encryption via `encrypted = true` |
| **IRSA** | Native AWS IAM integration for pod-level permissions (AWS only) |
| **IMDSv2** | Enforced by default (`http_tokens = "required"`) |
| **Kubespan encryption** | All inter-node traffic encrypted with WireGuard |

## Troubleshooting

<details>
<summary><strong>Nodes not joining the cluster</strong></summary>

1. Check Kubespan connectivity:
   ```bash
   talosctl --talosconfig talosconfig get kubespanpeerstatus
   ```

2. Verify discovery service:
   ```bash
   talosctl --talosconfig talosconfig get discoveredmembers
   ```

3. Check firewall rules allow:
   - UDP 51820 (WireGuard)
   - TCP 50000-50001 (Talos API)

</details>

<details>
<summary><strong>etcd issues</strong></summary>

1. Check etcd member list:
   ```bash
   talosctl --talosconfig talosconfig etcd members
   ```

2. Check etcd status:
   ```bash
   talosctl --talosconfig talosconfig service etcd
   ```

3. For quorum loss, see [Talos disaster recovery](https://www.talos.dev/latest/advanced/disaster-recovery/)

</details>

<details>
<summary><strong>Control plane not bootstrapping</strong></summary>

1. Ensure NLB health checks are passing (port 6443)
2. Check bootstrap status:
   ```bash
   talosctl --talosconfig talosconfig bootstrap --nodes <first-cp-ip>
   ```
3. Review machine config:
   ```bash
   talosctl --talosconfig talosconfig get machineconfig
   ```

</details>

## Contributing

Contributions are welcome! Please read our [Contributing Guide](./CONTRIBUTING.md) before submitting a PR.

### Development Setup

```bash
# Install pre-commit hooks
pre-commit install

# Run checks
pre-commit run -a
```

### Adding a New Cloud Provider

1. Create `modules/control-plane/<provider>/`
2. Create `modules/node-pools/<provider>/`
3. Add example in `examples/`
4. Update this README

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- [Talos Linux](https://www.talos.dev/) by Sidero Labs
- [terraform-aws-modules](https://github.com/terraform-aws-modules) for AWS patterns
- [terraform-google-modules](https://github.com/terraform-google-modules) for GCP patterns
