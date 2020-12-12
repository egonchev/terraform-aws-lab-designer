vpc = {
    vpc_name        = "vpc-wp",
    vpc_cidr_block  = "10.0.0.0/16",
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"],
    private_subnets = ["10.0.21.0/24", "10.0.22.0/24"]
}

ec2_instances = {
    bastion = {
      private_ip                  = "10.0.1.10",
      associate_public_ip_address = true,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/wordpress/install_bastion.sh"]
    }, 
    swarm-manager = {
      private_ip                  = "10.0.21.10",
      associate_public_ip_address = false,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/wordpress/install_swarm_manager.sh"]
    },  
    wordpress = {
      private_ip                  = "10.0.21.11",
      associate_public_ip_address = false,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/wordpress/install_swarm_worker.sh", "var_manager_ip=10.0.21.10"]
    },
    db = {
      private_ip                  = "10.0.22.10",
      associate_public_ip_address = false,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/wordpress/install_swarm_worker.sh", "var_manager_ip = 10.0.21.10"],
    }
}

services = {
    ssh-external-access = {
      from              = ["0.0.0.0/0"],
      targets           = {
        "bastion"       = ["22/tcp"]
      }
    },
    ssh-internal-hosts  = {
      from              = ["10.0.1.10/32"],
      targets           = {
        "wordpress"     = ["22/tcp"],
        "db"            = ["22/tcp"], 
        "swarm-manager" = ["22/tcp"]
      }
    },
    db = {
      from              = ["10.0.21.11/32"],
      targets           = {
        "db"            = ["3306/tcp", "33060/tcp"]
      }
    }, 
    docker = {
      from              = ["self"],
      targets           = {
        "swarm-manager" = ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"],
        "wordpress"     = ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"],
        "db"            = ["4789/udp", "7946/tcp", "2377/tcp", "2375/tcp"]
      }
    },     
    load_balancer       = {
      from              = ["self", "0.0.0.0/0"],
      targets           = {
        "wordpress"     = ["443/tcp"],
        "swarm-manager" = ["9000/tcp"]
      }
    }
}
