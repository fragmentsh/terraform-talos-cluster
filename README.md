# Terraform Talos Cluster

[![Pre-Commit](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/pre-commit.yml)
[![Release](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/release.yml/badge.svg)](https://github.com/fragmentsh/terraform-talos-cluster/actions/workflows/release.yml)

Production-ready Terraform modules for deploying **hybrid [Talos](https://www.talos.dev/) Kubernetes clusters** across multiple cloud providers and regions.

## Why This Project?

The main goal is to replicate a managed control plane where you can bring your own node, especially bare metal one, while having a your control plane running in the cloud with all the benefits.

By leveraging Talos and Kubespan, this project enable hybrid Kubernetges clusters with a single control plane and worker nodes across multiple clouds and on-premises environments.

## Architecture

### Key Design Decisions

| Decision                     | Rationale                                                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Decoupled control plane**  | Control plane and node pools are separate modules, similar to managed Kubernetes. This allows node pools in different regions/clouds while maintaining a stable control plane. |
| **Kubespan mesh networking** | Built-in WireGuard-based mesh network connects all nodes regardless of network topology. No VPN or peering required between clouds.                                            |
| **Immutable infrastructure** | Talos OS is API-managed, read-only, and minimal. No SSH, no shell, no package manager = reduced attack surface.                                                                |

## Multi region node pools on cloud provider considerations

The main goal of this project is to provide a stable control plane, and cloud node pools with cloud provider integration to be able to run middleware, monitoring, etc. And then allow you to bring your own bare metal node.

The goal is not to provide a fully vertical cloud provider integration experience as cloud managed solutions already provides this experience but with some locking (GKE, EKS, etc).

If you wish to experiment with cloud multi-region node pools, running in multiple regions of the same cloud provider has some downside and trade off. Depending on the target architecture issue may arises. I've tried to compile findings below.

### AWS control plane with AWS node pools in different regions

> **Important**: While you can technically run AWS node pools in multiple regions (e.g., `us-west-2` + `eu-west-1`), cloud-provider-specific components are **single-region by design**:
>
> - **AWS Cloud Controller Manager** - single region only
> - **AWS EBS CSI Driver** - volumes are regional, cannot attach cross-region
> - **AWS Load Balancer Controller** - creates load balancers in one region in only one VPC
> - **Cluster Autoscaler** - manage ASG in a single region

Which means that only one node pool will be able to leverage the above components fully. The node pools in the secondary region will not be able to provision EBS volumes, use AWS load balancers, or be managed by the cluster-autoscaler.

This setup can be appropriate if you need fully stateless worker node.

> **Warning - AWS CCM Node Lifecycle**: If running node pools in multiple AWS regions, you **must disable** the AWS Cloud Controller Manager's node lifecycle controller. When enabled, the CCM will attempt to delete nodes it cannot find in its configured region, causing all nodes in other regions to be removed from the cluster.

### AWS control plane with AWS node pool in the same region and GCP node pool in another region

This setup should work as long as you only use 1 region in each cloud provider, you should be able to leverage the cloud provider integrations of each cloud.

## Best practice for hybrid deployments

> - Use a **single cloud provider region** for control plane + node pools in the same region on the same cloud provider
> - Deploy node pools in the same region of another cloud provider
> - Bring your own bare metal nodes

## Supported Cloud Providers

| Provider   | Control Plane | Node Pools | Status                |
| ---------- | ------------- | ---------- | --------------------- |
| **AWS**    | ✅            | ✅         | Production-ready      |
| **GCP**    | ✅            | ✅         | Production-ready      |
| Azure      | ❌            | ❌         | Contributions welcome |
| Bare Metal | ❌            | ❌         | Contributions welcome |

## Prerequisites

### Requirements

| Tool                                                                            | Version  | Purpose                                |
| ------------------------------------------------------------------------------- | -------- | -------------------------------------- |
| [Terraform](https://www.terraform.io/downloads)                                 | >= 1.5.7 | Infrastructure provisioning            |
| [talosctl](https://www.talos.dev/latest/introduction/getting-started/#talosctl) | >= 1.6.0 | Talos cluster management               |
| [kubectl](https://kubernetes.io/docs/tasks/tools/)                              | >= 1.28  | Kubernetes management                  |
| [OpenSSL](https://www.openssl.org/)                                             | Any      | Required for IRSA key generation (AWS) |

## Modules

### Control Plane Modules

| Module                                           | Description                                                         | Documentation                                   |
| ------------------------------------------------ | ------------------------------------------------------------------- | ----------------------------------------------- |
| [control-plane/aws](./modules/control-plane/aws) | AWS control plane with NLB, IRSA support, and CloudWatch monitoring | [README](./modules/control-plane/aws/README.md) |
| [control-plane/gcp](./modules/control-plane/gcp) | GCP control plane with regional MIG and external load balancer      | [README](./modules/control-plane/gcp/README.md) |

### Node Pool Modules

| Module                                     | Description                                                                | Documentation                                |
| ------------------------------------------ | -------------------------------------------------------------------------- | -------------------------------------------- |
| [node-pools/aws](./modules/node-pools/aws) | AWS worker nodes with ASG, rolling updates, and Cluster Autoscaler support | [README](./modules/node-pools/aws/README.md) |
| [node-pools/gcp](./modules/node-pools/gcp) | GCP worker nodes with regional MIG                                         | [README](./modules/node-pools/gcp/README.md) |

### Utility Modules

| Module                                         | Description                                          | Documentation                                  |
| ---------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| [cloud-images/aws](./modules/cloud-images/aws) | Lookup official Talos AMI IDs by version and region  | [README](./modules/cloud-images/aws/README.md) |
| [factory](./modules/factory)                   | Build and upload custom Talos images with extensions | [README](./modules/factory/README.md)          |

## Examples

| Example                             | Description                                                                            |
| ----------------------------------- | -------------------------------------------------------------------------------------- |
| [hybrid-aws](./examples/hybrid-aws) | Complete AWS deployment with control plane, node pools, Cilium CNI, and common add-ons |
| [hybrid-gcp](./examples/hybrid-gcp) | Complete GCP deployment with multi-region node pools                                   |

## Post-Deployment

### Install a CNI (Required)

The cluster ships without a CNI but Cilium deployments is present the examples folders.

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

| Feature                 | Implementation                                                  |
| ----------------------- | --------------------------------------------------------------- |
| **No SSH**              | Talos has no SSH daemon. All management via Talos API.          |
| **Mutual TLS**          | All Talos API calls use client certificates                     |
| **Encrypted at rest**   | Enable EBS encryption via `encrypted = true`                    |
| **IRSA**                | Native AWS IAM integration for pod-level permissions (AWS only) |
| **IMDSv2**              | Enforced by default (`http_tokens = "required"`)                |
| **Kubespan encryption** | All inter-node traffic encrypted with WireGuard                 |

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
