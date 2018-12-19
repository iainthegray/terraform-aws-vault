# Packer Scripts

There are 2 packer configs in this directory
* vault_install.json - A packer script to install vault with consul client.
* consul_install.json - A packer script to install consul

All inputs are variables and are explained here:
* "install_bucket": An S3 bucket where the vault binary and TLS cert and key are stored,
* "vault_bin": The name of the vault binary,
* "consul_version": The version of consul you want installed. This should be in the format of the consul binary on the [releases page](https://releases.hashicorp.com/consul/)
* "key": The name of the TLS private key,
* "cert": The name of the TLS cert,
* "source_ami": The AWS AMI_ID to use as a base. This script has been tested on Centos 7 and Ubuntu 18.04
* "os_version_tag": The tag for the OS
* "ssh_user": The ssh user packer should use. This is "ubuntu" or "centos"
* "aws_region": The region to build in
* "inst_type": Instance type
* "inst_profile": The instance profile name that Packer can use. This can be built with the sub-module in modules/packer_roles
* "tag": The consul cluster tag value for consul cluster joining
* "siz": The number of consul servers expected in the cluster.

The install_files dir contains the install scripts that do the actual lifting for the install.

## Usage
To run this you will need to copy the Vault binary to the install S3 bucket and the TLS key and cert required for TLS
