# Vault AWS Module

This repo contains a module for how to deploy a [Vault](https://www.vaultproject.io/) cluster on [AWS](https://aws.amazon.com/) using [Terraform](https://www.terraform.io/). It follows the patterns laid out in the [Vault Reference Architecture](https://learn.hashicorp.com/vault/operations/ops-reference-architecture) and the [Vault Deployment Guide](https://www.vaultproject.io/guides/operations/deployment-guide.html).

This module includes:

* A terraform module to install Vault into AWS.
* A packer directory containing the packer code to build Vault and Consul AMIs
* A userdata sub-module that can be referenced in the main Vault module to install and configure Vault in the approved best practice laid out in the [Deployment Guide](https://www.vaultproject.io/guides/operations/deployment-guide.html).

## Setup
This module is specifically designed to deliver the [Reference Architecture](https://learn.hashicorp.com/vault/operations/ops-reference-architecture) and as such adheres to that pattern. This means that it has these specifics that are not configurable:
* A Vault cluster using TLS
* The Vault cluster is backed by a consul cluster for storage
* The Vault cluster is intended to be deployed into a _private_ subnet(s)
* The security groups attached to the vault and consul cluster members are non-configurable and allow for full functionality (see below)

The module has these specifics that are configurable:
* The Vault cluster can be set up as _n_ standalone instances or inside an ASG depending on your preference.
* The Vault cluster can be fronted by an _internal_ ELB or not, depending on your preference.
* The number of Vault nodes can be configured, though 3 is the default and recommended number
* The number of Consul nodes can be configured though 3 is the default, 5 can be used.
* The recommended architecture suggests that the 3 Vault nodes be spread across 3 separate availability zones, but this module will take fewer than that.
* While this module manages the security groups to allow for the correct function of the cluster, it is possible to add further security groups to the instances if other connectivity is desired.

## Usage
```hcl
module vault_cluster {

  # This source should be the tag for this module if pulling from git
  source                 = "../terraform-aws-vault/modules/vault-cluster"

  instance_type          = "${var.instance_type}"
  ssh_key_name           = "${var.ssh_key_name}"
  cluster_name           = "${var.cluster_name}"
  ami_id                 = "${var.ami_id}"
  private_subnets        = "${module.vpc.private_subnets}"
  vpc_id                 = "${module.vpc.vpc_id}"
  availability_zones     = "${var.availability_zones}"

  # This is where you can add additional security groups to allow for such things as SSH access and access to the API

  additional_sg_ids = [
    "${aws_security_group.private_instances_sg.id}",
    "${aws_security_group.vault_cluster_ext.id}",
  ]

  # This variable is a boolean that determines whether the vault cluster is provisioned inside an ASG.

  use_asg           = false

  # This variable is a boolean that determines whether the vault cluster is provisioned behind an ELB
  use_elb           = false
}
```
