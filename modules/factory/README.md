<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | < 8.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | < 8.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.10.0-beta.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | < 8.0.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0-beta.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gcs_bucket"></a> [gcs\_bucket](#module\_gcs\_bucket) | terraform-google-modules/cloud-storage/google | ~> 12.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5 |

## Resources

| Name | Type |
|------|------|
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami) | resource |
| [aws_ami_copy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami_copy) | resource |
| [aws_ebs_snapshot_import.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_snapshot_import) | resource |
| [aws_iam_policy.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_object.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [google-beta_google_compute_image.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_image) | resource |
| [google-beta_google_storage_bucket_object.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_storage_bucket_object) | resource |
| [terraform_data.this](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/0.10.0-beta.0/docs/data-sources/image_factory_urls) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws"></a> [aws](#input\_aws) | n/a | <pre>object({<br/>    create_bucket          = optional(bool, true)<br/>    bucket_name            = optional(string, "talos-images")<br/>    tags                   = optional(map(string), {})<br/>    region                 = optional(string, "eu-west-1")<br/>    ami_additional_regions = optional(list(string), ["eu-west-1"])<br/>    import_iam_role        = optional(string, "vmimport")<br/>    create_iam_role        = optional(bool, true)<br/>    partition              = optional(string, "aws")<br/>  })</pre> | `null` | no |
| <a name="input_gcp"></a> [gcp](#input\_gcp) | n/a | <pre>object({<br/>    create_bucket     = optional(bool, true)<br/>    project_id        = string<br/>    bucket_name       = optional(string, "talos-images")<br/>    storage_locations = optional(list(string), ["eu"])<br/>  })</pre> | `null` | no |
| <a name="input_image_upload_platform"></a> [image\_upload\_platform](#input\_image\_upload\_platform) | n/a | `string` | n/a | yes |
| <a name="input_talos_architecture"></a> [talos\_architecture](#input\_talos\_architecture) | n/a | `string` | `"amd64"` | no |
| <a name="input_talos_platform"></a> [talos\_platform](#input\_talos\_platform) | n/a | `string` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | n/a | `string` | `"v1.11.6"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_talos_image"></a> [talos\_image](#output\_talos\_image) | n/a |
<!-- END_TF_DOCS -->
