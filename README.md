# terraform-talos-cluster

[![terraform-kubernetes-addons](https://github.com/fragmentsh/terraform-kubernetes-addons/workflows/terraform-kubernetes-addons/badge.svg)](https://github.com/fragmentsh/terraform-kubernetes-addons/actions?query=workflow%3Aterraform-kubernetes-addons)

## About

Set of modules to help deploy hybrids [Talos](https://www.talos.dev/) Kubernetes clusters.

## Architecture

- Control plane and node pools are decoupled, similar to a managed control plane

- [Kubespan](https://docs.siderolabs.com/talos/v1.9/networking/kubespan) is used to provide secure connectivity across networks

- Node pools can be deployed anywhere on any providers (eg. baremetal, AWS, GCP, etc.)

## Modules

Modules are available for various infrastructure providers.

Any contribution supporting a new cloud provider is welcomed.

### Control plane

- [GCP](./modules/control-plane/gcp)

### Node Pools

- [GCP](./modules/node-pools/gcp)

## Examples

- [GCP control plane with hybrid nodes pools on GCP](./examples/gcp)

## Pre-commit

```
pre-commit install
pre-commit run -a
```

Code formatting and documentation for variables and outputs is generated using
[pre-commit-terraform
hooks](https://github.com/antonbabenko/pre-commit-terraform) which uses
[terraform-docs](https://github.com/segmentio/terraform-docs).

## Contributing

Report issues/questions/feature requests on in the
[issues](https://github.com/fragmentsh/terraform-talos-cluster/issues/new)
section.

Full contributing [guidelines are covered
here](https://github.com/fragmentsh/terraform-talos-cluster/CONTRIBUTING.md).
