module "aws_ami" {
  source = "../../modules/cloud-images/aws"
  region = var.aws_region
  arch   = "amd64"
}
