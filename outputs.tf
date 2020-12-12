output "EC2_instances" {
  value = {
    for instance in module.environment.ec2_instances :
    instance.tags.Name => merge(
      map("Private IP", instance.private_ip),
      instance.public_ip=="" ? null : map("Public IP ", instance.public_ip),
      instance.public_ip=="" ? null : map("Public DNS", instance.public_dns),      
    )
  }
}

output "Load_balancer_Urls" {
  value =   sort(module.environment.alb_urls)
  #"Load balancer DNS": module.environment.lb_dns_name,
}
