provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "secondary"
  region = var.region_secondary
}

provider "helm" {
  kubernetes = {
    host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
    cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
    client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
    client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
  }
}

provider "kubernetes" {
  host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
  cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
  client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
  client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
}

provider "kubectl" {
  host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
  cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
  client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
  client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
  load_config_file       = false
}

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

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}

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

module "control_plane" {
  source = "../../modules/control-plane-static/aws"

  cluster_name = var.cluster_name
  vpc_id       = module.vpc_primary.vpc_id

  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  talos_image_id     = module.talos_ami.ami_id

  irsa = {
    enabled = true
  }

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = module.vpc_primary.public_subnets

    nodes = {
      "cp-0" = {}
      "cp-1" = {}
      "cp-2" = {}
    }

    root_volume = {
      size_gb = 5
      type    = "gp3"
    }

    ephemeral_volume = {
      enabled = true
      size_gb = 20
    }
  }

  nlb = {
    internal                   = false
    enable_deletion_protection = false
  }

  cloudwatch = {
    create_alarms = true
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

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
