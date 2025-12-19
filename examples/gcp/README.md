<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | < 8.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | < 8.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.10.0-beta.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0-beta.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_control_plane"></a> [control\_plane](#module\_control\_plane) | ../../modules/control-plane/gcp | n/a |
| <a name="module_network"></a> [network](#module\_network) | terraform-google-modules/network/google | ~> 13.0 |
| <a name="module_network_secondary"></a> [network\_secondary](#module\_network\_secondary) | terraform-google-modules/network/google | ~> 13.0 |
| <a name="module_node_pools"></a> [node\_pools](#module\_node\_pools) | ../../modules/node-pools/gcp | n/a |

## Resources

| Name | Type |
|------|------|
| [talos_client_configuration.talos](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/data-sources/client_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | `"talos-demo-cluster"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where resources will be created. | `string` | `"sandbox-archi-0"` | no |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created. | `string` | `"europe-west1"` | no |
| <a name="input_region_secondary"></a> [region\_secondary](#input\_region\_secondary) | The secondary GCP region for additional resources. | `string` | `"europe-west4"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_control_plane"></a> [control\_plane](#output\_control\_plane) | n/a |
| <a name="output_control_plane_api_url"></a> [control\_plane\_api\_url](#output\_control\_plane\_api\_url) | n/a |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | n/a |
| <a name="output_network"></a> [network](#output\_network) | n/a |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | n/a |
<!-- END_TF_DOCS -->
