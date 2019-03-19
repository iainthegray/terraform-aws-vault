#  Variables file

variable "ssh_key_name" {
  description = "The AWS ssh key to use to build instances"
}

variable "cluster_name" {
  description = "The name of the Vault cluster (e.g. vault-stage). This variable is used to namespace all resources created by this module."
}

variable "ami_id" {
  description = "The ID of the AMI to run in this cluster. Should be an AMI that had Vault installed and configured by the install-vault module."
}
variable "vault_ami_id" {
  description = "The ID of the AMI to run vault in this cluster."
}

variable "consul_ami_id" {
  description = "The ID of the AMI to run consul in this cluster."
}

variable "instance_type" {
  description = "The type of EC2 Instances to run for each node in the cluster (e.g. t2.micro)."
}

variable "global_region" {
  description = "the region vault cluster will be deployed into"
  type        = "string"
}

variable "availability_zones" {
  description = "A list AZs the vault cluster will be deployed into"
  type        = "list"
}

variable "private_subnets_cidr" {
  description = "A list private subnet cidr blocks"
  type        = "list"
}

variable "public_subnets_cidr" {
  description = "A list public subnet cidr blocks"
  type        = "list"
}

variable "vault_cluster_size" {
  description = "The size (number of instances) in the Vault cluster"
  default     = 3
}

variable "consul_cluster_size" {
  description = "The size (number of instances) in the consul cluster"
  default     = 3
}

variable "my_user" {
  description = "the user for the S3 bucket access"
  default = ""
}

variable "my_bucket" {
  description = "The S3 bucket for install"
}

variable "create_bucket" {
  description = "Should the S3 bucket be created"
  default = false
}

variable "create_user_access" {
  description = "Should we create user access for the S3 bucket for install"
  default = false
}
