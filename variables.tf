variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type_web" {
  description = "Instance type for web servers"
  default     = "t3.micro"
}

variable "instance_type_db" {
  description = "Instance type for DB server"
  default     = "t3.small"
}

variable "instance_type_bastion" {
  description = "Instance type for bastion host"
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your IP address for SSH"
}

variable "key_name" {
  description = "AWS key pair name"
}