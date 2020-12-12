resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = file(var.ssh-key)
}

data "aws_ami" "amazon_linux_image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "ec2_instances" {
  for_each = var.ec2_instances_conf

  instance_type   = lookup(each.value, "ec2_instance_type", "t3.small")
  ami             = lookup(each.value, "ami_id", data.aws_ami.amazon_linux_image.id)
  tags            = {  Name = each.key  }
  key_name        = "ssh-key"
    
  security_groups = [
    for group, rule in var.services : aws_security_group.access[group].id
    if (contains(keys(rule.targets),"*") || contains(keys(rule.targets), each.key))
  ]

  subnet_id       = concat(module.vpc.public_subnets, module.vpc.private_subnets)[
    index(local.vpc_subnets,
    format("%s/%s",cidrhost(format("%s/%s",split("/",each.value.private_ip)[0],split("/",var.vpc_conf.public_subnets[0])[1]),0),
    split("/",var.vpc_conf.public_subnets[0])[1]))
  ]

  private_ip                  = contains(local.vpc_subnets, lookup(each.value, "private_ip")) ? "" : lookup(each.value, "private_ip","") 
  associate_public_ip_address = lookup(each.value, "associate_public_ip_address", "false")
  
  root_block_device {
    volume_size = lookup(each.value, "volume_size",0)
  }

  user_data = fileexists(lookup(each.value,"bootstrap_script",[" "])[0]) ? templatefile(each.value.bootstrap_script[0],
    length(each.value.bootstrap_script) ==1 ? {var_hostname = each.key, var_os_user = each.value.os_user} : merge(
      {"var_hostname" = each.key, "var_os_user" = lookup(each.value, "os_user", "ec2-user")},
      zipmap([ for item in slice( each.value.bootstrap_script, 1, length( each.value.bootstrap_script )): trimspace(split("=",item)[0]) ],
             [ for item in slice( each.value.bootstrap_script, 1, length( each.value.bootstrap_script )): trimspace(split("=",item)[1]) ]
      )
    )
  ) : ""

  depends_on         = [ null_resource.natgw_dependency ]
}

