provider "aws" {
  profile    = "default"
  region     = var.aws_region
  access_key = var.aws_account_keys.access_key
  secret_key = var.aws_account_keys.secret_key
}

module "environment" {
  source                = "./environment"

  providers             = { aws = aws }
  ssh-key               = var.ssh-key
  tls-certificate       = var.tls-certificate
  vpc_conf              = var.vpc
  ec2_instances_conf    = var.ec2_instances
  services              = var.services
}
