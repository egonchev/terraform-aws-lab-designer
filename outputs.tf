output "ec2_instances" {
  value = {
    for instance in aws_instance.ec2_instances :
    instance.tags.Name => merge(
      map("Instance ID", instance.id),
      instance.public_ip == "" ? null : map("Public IP", instance.public_ip),
      map("Private IP", instance.private_ip)
    )
  }
}

output "load_balancer_url" {
  value = {
  "Load balancer DNS": module.alb.this_lb_dns_name,
  "Service urls": [ for port in sort(flatten(setunion(values(var.network_services["web_access"].targets)))): format("https://${module.alb.this_lb_dns_name}:%s",split("/",port)[0]) ]
  }
}
