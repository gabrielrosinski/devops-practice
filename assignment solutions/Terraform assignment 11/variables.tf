variable "aws_region" {
    description = "AWS region to deploy resources"
    default     = "us-east-1"
    type        = string
}

variable "key_name" {
    description = "Name of an existing EC2 key pair (for SSH)"
    type        = string
}

variable "ssh_ingress_cidr" {
    description = "CIDR allowed to SSH (use your public IP/32)"
    type        = string
}

