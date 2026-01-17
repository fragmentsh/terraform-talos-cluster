terraform {
  required_version = ">= 1.5.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "< 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "< 8.0.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }
  }
}
