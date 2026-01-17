variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1"
}

variable "talos_version" {
  description = "The version of Talos OS to use."
  type        = string
  default     = "v1.12.1"
}
