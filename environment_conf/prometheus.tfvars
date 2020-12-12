vpc = {
    vpc_name        = "vpc-prom"
    vpc_cidr_block  = "10.0.0.0/16",
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"],
    private_subnets = ["10.0.21.0/24", "10.0.22.0/24"]
}

ec2_instances = {
    prometheus = {
      private_ip                  = "10.0.1.10",
      associate_public_ip_address = true,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/prometheus_grafana/setup_prometheus.sh"]
    },
    grafana = {
      private_ip                  = "10.0.2.10",
      associate_public_ip_address = true,
      os_user                     = "ec2-user",
      bootstrap_script            = ["./environment_conf/prometheus_grafana/setup_grafana.sh"]
    }   
}

services = {
    ssh-external-access = {
      from              = ["0.0.0.0/0"],     # Specify IP address here if SSH access need to be restricted
      targets           = {
        "prometheus"    = ["22/tcp"],
        "grafana"       = ["22/tcp"]        
      }
    },
    application         = {
      from              = ["self"],
      targets           = {
        "prometheus"    = ["22/tcp", "9090/tcp", "9093/tcp", "3000/tcp", "8080/tcp", "9100/tcp"], 
        "grafana"       = ["22/tcp", "9090/tcp", "9093/tcp", "3000/tcp", "8080/tcp", "9100/tcp"]
      }
    },    
    load_balancer       = {
      from              = ["self", "0.0.0.0/0"],
      targets           = {
        "prometheus"    = ["9090/https", "9093/https"],
        "grafana"       = ["3000/https"]
      }
    }
}
