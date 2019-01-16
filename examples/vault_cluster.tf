/*--------------------------------------------------------------
 Vault cluster
 This is an example for using the vault cluster module.
--------------------------------------------------------------*/
module vault_cluster {
  source        = "../terraform-aws-vault"
  instance_type = "${var.instance_type}"
  ssh_key_name  = "${var.ssh_key_name}"

  additional_sg_ids = [
    "${aws_security_group.private_instances_sg.id}",
    "${aws_security_group.vault_cluster_ext.id}",
  ]

  cluster_name       = "${var.cluster_name}"
  vault_ami_id       = "${var.ami_id}"
  consul_ami_id      = "${var.ami_id}"
  private_subnets    = "${module.vpc.private_subnets}"
  vpc_id             = "${module.vpc.vpc_id}"
  use_asg            = false
  use_elb            = false
  availability_zones = "${var.availability_zones}"

  # Userdata stuff
  use_userdata   = true
  install_bucket = "${var.my_bucket}"
  # vault_bin      = "vault.zip"
  vault_version  = "1.0.1"
  key_pem        = "key.pem"
  cert_pem       = "cert.pem"
  # consul_version = "1.3.1"
  consul_bin     = "consul_1.3.1_linux_386.zip"
  consul_cluster_size   = "${var.consul_cluster_size}"
}

/*--------------------------------------------------------------
 Vault cluster External access Security Group
 This is a new security group that allows vault and consul ui
 access form the bastion.
 It also allows ssh to the cluster form the bastion
--------------------------------------------------------------*/
resource "aws_security_group" "vault_cluster_ext" {
  name        = "vault_cluster_ext"
  description = "The SG for vault Servers External Access"
  vpc_id      = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_ingress_8200" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  description              = "Vault HTTP API"
  security_group_id        = "${aws_security_group.vault_cluster_ext.id}"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_ingress_8500" {
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  description              = "Consul HTTP API"
  security_group_id        = "${aws_security_group.vault_cluster_ext.id}"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_ingress_8600" {
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  description              = "Consul DNS interface"
  security_group_id        = "${aws_security_group.vault_cluster_ext.id}"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
}

/*--------------------------------------------------------------
 Private S3 bucket
 This can be created by the terraform or you can assign an already created one
--------------------------------------------------------------*/
module private_s3 {
  source = "../terraform-aws-vault/modules/private-s3"
  global_region = "${var.global_region}"
  create_bucket = "${var.create_bucket}"
  create_user_access = "${var.create_user_access}"
  my_user = "${var.my_user}"
  bucket_name = "${var.my_bucket}"
  cluster_server_role = "${module.vault_cluster.cluster_server_role}"
}
