# Find the latest Ubuntu 24.04 LTS (Noble) AMD64 HVM EBS AMI from Canonical
data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

# Security group: allow SSH only from your IP; all egress allowed
resource "aws_security_group" "ssh_only" {
    name        = "tf-ssh-only"
    description = "Allow SSH from my IP, all egress allowed"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Use default VPC + a default subnet
data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default_subnets" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

locals {
    subnet_id = data.aws_subnets.default_subnets.ids[0]
}

resource "aws_instance" "ubuntu" {
    ami                         = data.aws_ami.ubuntu.id
    instance_type               = "t2.micro"
    subnet_id                   = local.subnet_id
    key_name                    = var.key_name
    vpc_security_group_ids      = [aws_security_group.ssh_only.id]
    associate_public_ip_address = true
    disable_api_termination     = true

    tags = {
      Name = "tf-ubuntu"
    }
}