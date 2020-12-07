resource "aws_key_pair" "ssh-key" {
  provider   = aws.provider
  key_name   = "ssh-key"
  public_key = file(var.ssh-key)
}

data "aws_ami" "amazon_linux_image" {
  provider    = aws.provider
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "ec2_instances" {
  for_each = var.ec2_instances

  provider        = aws.provider
  instance_type   = lookup(each.value, "ec2_instance_type", "t3.small")
  ami             = lookup(each.value, "ami_id", data.aws_ami.amazon_linux_image.id)

  security_groups = [
    for sg, rule in var.network_services : aws_security_group.access[sg].id
    if (contains(keys(rule.targets),"*") || contains(keys(rule.targets), each.key))
  ]

  key_name        = "ssh-key"
  subnet_id       = concat(module.vpc.public_subnets, module.vpc.private_subnets)[
    index(concat(var.vpc_network.public_subnets, var.vpc_network.private_subnets),
    format("%s/%s",cidrhost(format("%s/%s",split("/",each.value.private_ip)[0],split("/",var.vpc_network.public_subnets[0])[1]),0),
    split("/",var.vpc_network.public_subnets[0])[1]))
  ]

  private_ip                  = contains(concat(var.vpc_network.public_subnets, var.vpc_network.private_subnets),lookup(each.value, "private_ip")) ? "" : lookup(each.value, "private_ip","") 
  associate_public_ip_address = lookup(each.value, "associate_public_ip_address", "false")

  tags = {
    Name = each.key
  }

  user_data          = templatefile(
    each.value.bootstrap_script,
    {
      var_hostname   = each.key, 
      var_os_user    = each.value.os_user,
      var_manager_ip = lookup(each.value,"swarm_manager_ip","")
    }
  )

  depends_on         = [null_resource.natgw_dependency]

  provisioner "local-exec" {
    command = <<EOF
      aws --profile "default" ec2 wait instance-status-ok --region ${var.aws_region} --instance-ids ${self.id}
    EOF
  }
}

