provider "aws" {
  region  = "${var.global_region}"
  version = "~> 1.50"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.53.0"

  name = "base_vpc"

  cidr = "10.0.0.0/16"

  azs             = "${var.availability_zones}"
  private_subnets = "${var.private_subnets_cidr}"
  public_subnets  = "${var.public_subnets_cidr}"

  assign_generated_ipv6_cidr_block = false

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "public_sn"
  }

  tags = {
    Purpose     = "vault_DG"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "base_vpc"
  }
}

resource "aws_security_group" "bastion_sg" {
  description = "Enable SSH access to the bastion via SSH port"
  name        = "bastion-security-group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for private instances
resource "aws_security_group" "private_instances_sg" {
  description = "Enable SSH access to the Private instances from the bastion via SSH port"
  name        = "private-security-group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    protocol  = "TCP"
    to_port   = 22

    security_groups = [
      "${aws_security_group.bastion_sg.id}",
    ]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion resource
resource "aws_instance" "bastion" {
  ami                         = "${var.ami_id}"
  instance_type               = "${var.instance_type}"
  associate_public_ip_address = true
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${aws_security_group.bastion_sg.id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"

  tags = {
    Name = "Bastion"
  }
}
