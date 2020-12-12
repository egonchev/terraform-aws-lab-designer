module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name               = var.name
  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.subnets
  security_groups = var.security_groups

  target_groups = [for port in var.services_ports:
    {
      name_prefix      = format("%s", port[1])
      backend_protocol = "HTTP"
      backend_port     = port[1]
      target_type      = "instance"
    } 
  ]
  
  http_tcp_listeners = [for port in var.services_ports:
    {
      protocol            = "HTTP"
      port                = port[1] 
      target_group_index  = index(var.services_ports,port)
    } if contains(["http","tcp"],port[2])
  ]
  
  https_listeners = [for port in var.services_ports:
    {
      protocol            = "HTTPS"
      port                = port[1]
      certificate_arn     = var.certificate_arn
      target_group_index  = index(var.services_ports,port)
    } if port[2] == "https"
  ]
}

resource "aws_alb_target_group_attachment" "svc_physical_external" {
  for_each         =  { for pair in setproduct(var.services_ports,
                        keys(var.web_services)): "${pair[0][0]}:${pair[1]}" => pair 
                        if contains( var.web_services[pair[1]], pair[0][0] )
                      }

  target_group_arn = module.alb.target_group_arns[ index(var.services_ports, each.value[0]) ]
  target_id        = var.ec2_instances[each.value[1]].id
  port             = each.value[0][1]
}
