provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "secondary"
  region = var.region_secondary
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.talos.kubernetes_client_configuration.host
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_key)
  }
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.talos.kubernetes_client_configuration.host
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.ca_certificate)
  client_certificate     = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_key)
}

provider "kubectl" {
  host                   = talos_cluster_kubeconfig.talos.kubernetes_client_configuration.host
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.ca_certificate)
  client_certificate     = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_key)
  load_config_file       = false
}

# -----------------------------------------------------------------------------
# Talos Cloud Images - Fetch official Talos AMI IDs
# -----------------------------------------------------------------------------

module "talos_ami" {
  source        = "../../modules/cloud-images/aws"
  talos_version = var.talos_version
  region        = var.region
}

module "talos_ami_secondary" {
  source = "../../modules/cloud-images/aws"

  talos_version = var.talos_version
  region        = var.region_secondary
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}

# -----------------------------------------------------------------------------
# Primary Region VPC
# -----------------------------------------------------------------------------

module "vpc_primary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.cluster_name
  cidr = "10.42.0.0/16"

  azs             = slice(data.aws_availability_zones.primary.names, 0, 3)
  private_subnets = ["10.42.1.0/24", "10.42.2.0/24", "10.42.3.0/24"]
  public_subnets  = ["10.42.101.0/24", "10.42.102.0/24", "10.42.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
    Cluster     = var.cluster_name
  }
}

# -----------------------------------------------------------------------------
# Secondary Region VPC (for hybrid node pools)
# -----------------------------------------------------------------------------

module "vpc_secondary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  providers = {
    aws = aws.secondary
  }

  name = "${var.cluster_name}-secondary"
  cidr = "10.45.0.0/16"

  azs             = slice(data.aws_availability_zones.secondary.names, 0, 3)
  private_subnets = ["10.45.1.0/24", "10.45.2.0/24", "10.45.3.0/24"]
  public_subnets  = ["10.45.101.0/24", "10.45.102.0/24", "10.45.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
    Cluster     = var.cluster_name
  }
}

# -----------------------------------------------------------------------------
# Talos Control Plane (Primary Region)
# -----------------------------------------------------------------------------

module "control_plane" {
  source = "../../modules/control-plane/aws"

  cluster_name       = var.cluster_name
  region             = var.region
  availability_zones = slice(data.aws_availability_zones.primary.names, 0, 3)
  vpc_id             = module.vpc_primary.vpc_id

  subnet_ids = {
    for i, az in slice(data.aws_availability_zones.primary.names, 0, 3) :
    az => module.vpc_primary.public_subnets[i]
  }

  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  talos_image_id     = module.talos_ami.ami_id

  irsa = {
    enabled = true
  }

  control_plane = {
    instance_type = "m6i.large"

    nodes = {
      "0" = {
        update_launch_template_default_version = false
      }
      "1" = {
        update_launch_template_default_version = false
      }
      "2" = {
        update_launch_template_default_version = false
      }
    }

    root_volume = {
      size_gb = 50
      type    = "gp3"
    }

  }

  load_balancer = {
    internal                   = false
    enable_deletion_protection = false # Set to true in production
  }

  cloudwatch = {
    create_alarms = true
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

# -----------------------------------------------------------------------------
# Talos Client Configuration
# -----------------------------------------------------------------------------

data "talos_client_configuration" "talos" {
  cluster_name         = var.cluster_name
  client_configuration = module.control_plane.talos_client_configuration
  endpoints            = [module.control_plane.load_balancer.dns_name]
  nodes = concat(
    module.control_plane.private_ips,
    module.node_pools_primary.private_ips,
    module.node_pools_secondary.private_ips
  )
}

# -----------------------------------------------------------------------------
# Talos Cluster Health Check
# -----------------------------------------------------------------------------

#data "talos_cluster_health" "talos" {
#  depends_on           = [module.cilium]
#  client_configuration = module.control_plane.talos_client_configuration
#  control_plane_nodes  = module.control_plane.private_ips
#  worker_nodes = concat(
#    module.node_pools_primary.private_ips,
#    module.node_pools_secondary.private_ips
#  )
#  endpoints = [module.control_plane.load_balancer.dns_name]
#
#  timeouts = {
#    read = "10m"
#  }
#}

# -----------------------------------------------------------------------------
# Kubeconfig (after cluster is healthy)
# -----------------------------------------------------------------------------

resource "talos_cluster_kubeconfig" "talos" {
  client_configuration = module.control_plane.talos_client_configuration
  endpoint             = module.control_plane.load_balancer.dns_name
  node                 = module.control_plane.private_ips[0]
}

# -----------------------------------------------------------------------------
# Cilium CNI (Optional - uncomment to deploy)
# -----------------------------------------------------------------------------

module "cilium" {
  source = "/Users/klefevre/git/fragmentsh/terraform-kubernetes-addons//modules/talos"

  cluster_name = var.cluster_name

  addons = {
    cilium = {
      enabled = true
    }
  }
}

module "aws-cloud-controller-manager" {
  source = "/Users/klefevre/git/fragmentsh/terraform-kubernetes-addons//modules/talos"

  cluster_name = var.cluster_name

  addons = {
    aws-cloud-controller-manager = {
      enabled      = true
      extra_values = <<-EXTRA_VALUES
      image:
        tag: ${var.kubernetes_version}
      EXTRA_VALUES
    }
  }
}

module "cert-manager" {
  source = "/Users/klefevre/git/fragmentsh/terraform-kubernetes-addons//modules/aws"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    cert-manager = {
      enabled = true
      eks_pod_identity = {
        enabled = false
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Node Pools - Primary Region
# -----------------------------------------------------------------------------

module "node_pools_primary" {
  source = "../../modules/node-pools/aws"

  cluster_name   = var.cluster_name
  region         = var.region
  vpc_id         = module.vpc_primary.vpc_id
  talos_image_id = module.talos_ami.ami_id

  kubernetes_version         = var.kubernetes_version
  talos_version              = var.talos_version
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    default-ew1 = {
      instance_type    = "t3.medium"
      desired_capacity = 1
      min_size         = 1
      max_size         = 3
      subnet_ids       = module.vpc_primary.public_subnets

      labels = {
        "topology.kubernetes.io/region" = var.region
        "node-pool"                     = "primary"
      }

      enable_cluster_autoscaler = true
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

# -----------------------------------------------------------------------------
# Node Pools - Secondary Region (Hybrid)
# -----------------------------------------------------------------------------

module "node_pools_secondary" {
  source = "../../modules/node-pools/aws"

  providers = {
    aws = aws.secondary
  }

  cluster_name   = var.cluster_name
  region         = var.region_secondary
  vpc_id         = module.vpc_secondary.vpc_id
  talos_image_id = module.talos_ami_secondary.ami_id

  kubernetes_version         = var.kubernetes_version
  talos_version              = var.talos_version
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    default-ew3 = {
      instance_type    = "t3.medium"
      desired_capacity = 1
      min_size         = 1
      max_size         = 3
      subnet_ids       = module.vpc_secondary.public_subnets

      labels = {
        "topology.kubernetes.io/region" = var.region_secondary
        "node-pool"                     = "secondary"
      }

      enable_cluster_autoscaler = true
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}
