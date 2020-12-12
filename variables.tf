variable aws_region {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable aws_account_keys {
  description   = "AWS Account Access and Secret keys"
  type          = map(string)
  default       = {
    access_key  = "<ACCESS_KEY>",
    secret_key  = "<SECRET_KEY>"
  }
}

variable ssh-key {
  description = "SSH Key"
  type        = string
  default     = "./resources/keys/ssh_key.pub"
}

variable tls-certificate {
  description = "TLS certificate for Application load balancer HTTPS listeners"
  type        = map(string)
  default     = {
    name      = "example_cert"  
    crt       = "./resources/certificates/example.crt",
    key       = "./resources/certificates/example.key"
  }
}

variable vpc {}
variable ec2_instances {}
variable services {}
