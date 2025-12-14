variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
  default     = "sandbox-archi-0"
}

variable "region" {
  description = "The GCP region where resources will be created."
  type        = string
  default     = "europe-west1"
}

variable "region_secondary" {
  description = "The secondary GCP region for additional resources."
  type        = string
  default     = "europe-west4"
}

variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string
  default     = "talos-demo-cluster"
}
