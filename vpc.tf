provider "aws" {
  profile    = "default"
  region     = var.aws_region
  access_key = var.aws_account.access_key
  secret_key = var.aws_account.secret_key
  alias      = "provider"
}

data "aws_availability_zones" "azs" {
  provider = aws.provider
  state    = "available"
}

resource "aws_iam_server_certificate" "cert" {
  provider         = aws.provider
  name             = "example_cert"
  certificate_body = file("certificates/example.crt")
  private_key      = file("certificates/example.key")
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  providers = {
    aws = aws.provider
  }

  cidr = var.vpc_network.vpc_cidr_block
  azs = data.aws_availability_zones.azs.names

  public_subnets  = var.vpc_network.public_subnets
  private_subnets = var.vpc_network.private_subnets

  enable_dns_support      = true
  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false
  map_public_ip_on_launch = true

  tags = {
    Name = "my-vpc"
  }
}

resource "null_resource" "natgw_dependency" {
  depends_on = [module.vpc.natgw_ids, module.vpc.igw_id, module.vpc.private_nat_gateway_route_ids, module.vpc.private_route_table_ids, module.vpc.nat_ids]
  triggers = {
    natgw_id = module.vpc.natgw_ids[0]
  }
}

resource "aws_security_group" "access" {
  for_each    = var.network_services
  provider    = aws.provider
  name        = each.key
  description = each.key
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = each.key
  }

  dynamic "ingress" {
    for_each = {for pair in setproduct(sort(flatten(setunion(values(each.value.targets)))), each.value.from): "${pair[0]}:${pair[1]}"=>pair}
    content {
      from_port   = split("/",ingress.value[0])[0]
      to_port     = split("/",ingress.value[0])[0]
      protocol    = split("/",ingress.value[0])[1]
      cidr_blocks = ingress.value[1] == "self" ? []: list(ingress.value[1])
      self        = ingress.value[1] == "self"
    }
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  providers = {
    aws = aws.provider
  }

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [ aws_security_group.access["web_access"].id ]

  target_groups = [for port in sort(flatten(setunion(values(var.network_services["web_access"].targets)))):
    {
      name_prefix      = format("%s", split("/",port)[0])
      backend_protocol = "HTTP"
      backend_port     = split("/",port)[0]
      target_type      = "instance"
    }
  ]

  https_listeners = [for port in sort(flatten(setunion(values(var.network_services["web_access"].targets)))):
    {
      protocol            = "HTTPS"
      port                = split("/",port)[0] 
      certificate_arn     = aws_iam_server_certificate.cert.arn  
      target_group_index  = index(sort(flatten(setunion(values(var.network_services["web_access"].targets)))),port)
    }
  ]
}

resource "aws_alb_target_group_attachment" "svc_physical_external" {
  for_each         =  {for pair in setproduct(sort(flatten(setunion(values(var.network_services["web_access"].targets)))) , keys(var.network_services["web_access"].targets)): "${pair[0]}:${pair[1]}"=>pair if contains(var.network_services["web_access"].targets[pair[1]], pair[0])}
  provider         = aws.provider
  target_group_arn = module.alb.target_group_arns[index(sort(flatten(setunion(values(var.network_services["web_access"].targets)))), each.value[0])]
  target_id        = aws_instance.ec2_instances[each.value[1]].id
  port             = split("/",each.value[0])[0]
}
