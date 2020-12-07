variable aws_region {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable aws_account {
  description = "AWS Account Access and Secret keys"
  type        = map(string)
  default = {
    access_key  = "<ACCESS_KEY>",
    secret_key  = "<SECRET_KEY>"
  }
}

variable ssh-key {
  description = "SSH Key"
  type        = string
  default = "./keys/ssh_key.pub"
}

variable vpc_network {
  description = "VPC subnets cidr blocks"
  type        = any
  default = {
    vpc_cidr_block  = "10.0.0.0/16",
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"],
    private_subnets = ["10.0.21.0/24", "10.0.22.0/24"]
  }
}

variable "ec2_instances" {
  description = "EC2 instances properties"
  type        = any
  default = {
    bastion = {
      private_ip                  = "10.0.1.10",
      associate_public_ip_address = true,
      ec2_instance_type           = "t3.small",
      os_user                     = "ec2-user",
      bootstrap_script            = "./scripts/install_bastion.sh"
    }, 
    swarm-manager = {
      private_ip                  = "10.0.21.10",
      associate_public_ip_address = false,
      ec2_instance_type           = "t3.small",
      os_user                     = "ec2-user",
      bootstrap_script            = "./scripts/install_swarm_manager.sh"
    },  
    wordpress = {
      private_ip                  = "10.0.21.11",
      associate_public_ip_address = false,
      ec2_instance_type           = "t3.small",
      os_user                     = "ec2-user",
      bootstrap_script            = "./scripts/install_swarm_worker.sh",
      swarm_manager_ip            = "10.0.21.10"      
    },
    db = {
      private_ip                  = "10.0.22.10",
      associate_public_ip_address = false,
      ec2_instance_type           = "t3.small",
      os_user                     = "ec2-user",
      bootstrap_script            = "./scripts/install_swarm_worker.sh",
      swarm_manager_ip            = "10.0.21.10"
      # ami_id                    = "ami-096fda3c22c1c990a"
    }
  }
}

variable "network_services" {
  description = "Network Services"
  type        = any
  default = {
    ssh-external-access = {
      type      = "login",
      from      = ["0.0.0.0/0"],
      targets   = {
        "bastion": ["22/tcp"]
      },
    },
    ssh-internal-hosts = {
      type         = "login",
      from         = ["10.0.1.10/32"],
      targets      = {
        "wordpress": ["22/tcp"],
        "db":        ["22/tcp"], 
        "swarm-manager": ["22/tcp"]
      }
    },
    db = {
      type         = "db_access",
      from         = ["10.0.21.11/32"],
      targets      = {
        "db":        ["3306/tcp", "33060/tcp"]
      },
    }, 
    docker = {
      type         = "docker",
      from         = ["self"],
      targets      = {
        "swarm-manager": ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"],
        "wordpress":     ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"],
        "db":            ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"]
      }
    },     
    web_access = {
      type         = "web_access",
      from         = ["self", "0.0.0.0/0"],
      targets      = {
        "wordpress":     ["443/tcp"],
        "swarm-manager": ["9000/tcp"]
      },
    },
  }
}
