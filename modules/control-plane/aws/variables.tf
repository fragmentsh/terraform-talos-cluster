variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.cluster_name)) && length(var.cluster_name) <= 63
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, start and end with alphanumeric, and be at most 63 characters"
  }
}

variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones for control plane distribution. Nodes will be distributed across these zones using round-robin."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 1 && length(var.availability_zones) <= 6
    error_message = "Must provide between 1 and 6 availability zones"
  }
}

variable "vpc_id" {
  description = "ID of the VPC where control plane will be deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (vpc-xxxxx)"
  }
}

variable "subnet_ids" {
  description = "Map of availability zone to subnet ID for control plane placement."
  type        = map(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "Must provide at least one subnet"
  }
}

variable "talos_version" {
  description = "The version of Talos OS to use for the control plane instances."
  type        = string
  default     = "v1.11.6"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos_version))
    error_message = "Talos version must be in format vX.Y.Z"
  }
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy on the Talos control plane."
  type        = string
  default     = "v1.34.2"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format vX.Y.Z"
  }
}

variable "talos_image_id" {
  description = "Talos OS AMI ID. Use the cloud-images module to get the official AMI ID for your region."
  type        = string
}

variable "control_plane" {
  description = "Configuration for the control plane instances."
  type = object({
    # Default instance type (can be overridden per node)
    instance_type = string

    # Per-node configuration (keys must be numeric strings: "0", "1", "2", etc.)
    nodes = map(object({
      availability_zone                      = optional(string)      # Override AZ for this node
      instance_type                          = optional(string)      # Override instance type for this node
      update_launch_template_default_version = optional(bool, false) # When true, ASG uses $Latest version triggering instance refresh
      config_patches                         = optional(list(any))   # Additional Talos config patches for this node
      tags                                   = optional(map(string)) # Additional tags for this node
    }))

    # Root volume configuration (global)
    root_volume = optional(object({
      size_gb               = optional(number, 50)
      type                  = optional(string, "gp3")
      iops                  = optional(number, 3000)
      throughput            = optional(number, 125)
      encrypted             = optional(bool, true)
      kms_key_id            = optional(string)
      delete_on_termination = optional(bool, true)
    }), {})

    # Instance metadata configuration (IMDSv2)
    instance_metadata = optional(object({
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 1)
      instance_metadata_tags      = optional(string, "disabled")
    }), {})

    # ASG configuration (global)
    wait_for_capacity_timeout = optional(string, "10m")
    default_cooldown          = optional(number, 300)
    health_check_grace_period = optional(number, 300)
    health_check_type         = optional(string, "EC2")

    # Instance refresh configuration (for rolling updates)
    instance_refresh = optional(object({
      min_healthy_percentage       = optional(number, 0)
      max_healthy_percentage       = optional(number, 100)
      instance_warmup              = optional(number, 60)
      scale_in_protected_instances = optional(string, "Refresh")
    }), {})

    # Instance maintenance policy (for AWS-initiated maintenance)
    instance_maintenance_policy = optional(object({
      min_healthy_percentage = optional(number, 0)
      max_healthy_percentage = optional(number, 100)
    }), {})

    # Instance protection
    protect_from_scale_in = optional(bool, true)

    # Network configuration
    associate_public_ip = optional(bool, true)

    # Tags (global)
    tags = optional(map(string), {})

    # Talos configuration patches (global, applied to all nodes)
    config_patches = optional(list(any), [])
  })

  validation {
    condition     = length(var.control_plane.nodes) >= 1 && length(var.control_plane.nodes) % 2 == 1
    error_message = "Control plane must have an odd number of nodes (1, 3, 5, 7, etc.) for etcd quorum"
  }

  validation {
    condition     = alltrue([for k, v in var.control_plane.nodes : can(tonumber(k))])
    error_message = "Node keys must be numeric strings (e.g., \"0\", \"1\", \"2\")"
  }

  validation {
    condition     = var.control_plane.instance_type != ""
    error_message = "Default instance type cannot be empty"
  }
}

variable "load_balancer" {
  description = "Network Load Balancer configuration for Kubernetes API and Talos API."
  type = object({
    internal                         = optional(bool, false)
    enable_cross_zone_load_balancing = optional(bool, true)
    enable_deletion_protection       = optional(bool, true)

    # Kubernetes API target group configuration
    deregistration_delay = optional(number, 30)
    health_check = optional(object({
      enabled             = optional(bool, true)
      interval            = optional(number, 10)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 10)
      timeout             = optional(number, 5)
      port                = optional(number, 6443)
      protocol            = optional(string, "TCP")
    }), {})

    # Talos API target group configuration
    talos_api = optional(object({
      deregistration_delay = optional(number, 10)
      health_check = optional(object({
        enabled             = optional(bool, true)
        interval            = optional(number, 10)
        healthy_threshold   = optional(number, 2)
        unhealthy_threshold = optional(number, 10)
      }), {})
    }), {})

    tags = optional(map(string), {})
  })
  default = {}
}

variable "cloudwatch" {
  description = "CloudWatch monitoring and alerting configuration."
  type = object({
    create_alarms       = optional(bool, true)
    alarm_sns_topic_arn = optional(string)
    tags                = optional(map(string), {})
  })
  default = {}
}

variable "security_group" {
  description = "Security group configuration for control plane instances."
  type = object({
    # Additional ingress rules
    additional_ingress_rules = optional(list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })), [])

    # Additional egress rules (default allows all outbound)
    additional_egress_rules = optional(list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })), [])

    # Allowed CIDR blocks for API access
    api_ingress_cidr_blocks = optional(list(string), ["0.0.0.0/0"])

    tags = optional(map(string), {})
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
