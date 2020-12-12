data "aws_availability_zones" "azs" {
  state    = "available"
}

resource "aws_iam_server_certificate" "cert" {
  provisioner "local-exec" {
    command = "sleep 5"
  }
  name             = var.tls-certificate.name
  certificate_body = file(var.tls-certificate.crt)
  private_key      = file(var.tls-certificate.key)
  
  lifecycle {  create_before_destroy = true  }  
}

locals {
  services_ports = {
    for key,value in var.services: key=>[for port in sort(setunion(flatten(values(value.targets)))): concat([port],split("/",port))]
  }
  vpc_subnets = concat(var.vpc_conf.public_subnets, var.vpc_conf.private_subnets)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  cidr = var.vpc_conf.vpc_cidr_block
  azs = data.aws_availability_zones.azs.names

  public_subnets  = var.vpc_conf.public_subnets
  private_subnets = var.vpc_conf.private_subnets

  enable_dns_support      = true
  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false
  map_public_ip_on_launch = true

  tags = {  Name = var.vpc_conf.vpc_name  }
}

resource "null_resource" "natgw_dependency" {
  depends_on = [module.vpc.natgw_ids, module.vpc.igw_id]
  triggers = {
    natgw_id = module.vpc.natgw_ids[0]
  }
}

resource "aws_security_group" "access" {
  for_each    = var.services

  name        = each.key
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = each.key }

  dynamic     "ingress" {
    for_each  = { for pair in setproduct(local.services_ports[each.key], each.value.from): "${pair[0][0]}:${pair[1]}"=>pair }
    content {
      from_port   = ingress.value[0][1]
      to_port     = ingress.value[0][1]
      protocol    = contains(["tcp","http","https"], ingress.value[0][2]) ? "tcp" : ingress.value[0][2]
      cidr_blocks = ingress.value[1] == "self" ? [] : list(ingress.value[1])
      self        = ingress.value[1] == "self"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module alb {
  source = "./alb"
  count             = contains(keys(var.services),"load_balancer") ? 1 : 0

  name              = "alb-${var.vpc_conf.vpc_name}"
  vpc_id            = module.vpc.vpc_id
  subnets           = module.vpc.public_subnets
  security_groups   = [ aws_security_group.access["load_balancer"].id ]
  web_services      = var.services["load_balancer"].targets
  services_ports    = local.services_ports["load_balancer"]
  certificate_arn   = aws_iam_server_certificate.cert.arn
  ec2_instances     = aws_instance.ec2_instances
}
