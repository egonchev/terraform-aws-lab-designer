output "ec2_instances" {
    value = aws_instance.ec2_instances
}

output "vpc" {
  value = module.vpc
}
output "alb" {value = module.alb}
output "alb_urls" {
  value = [for port in local.services_ports.load_balancer: format("%s://${module.alb[0].lb_dns_name}:%s",port[2]=="https" ? "https" : "http",port[1])]
}

output "lb_dns_name" {
  value = module.alb[0].lb_dns_name
}
