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
  vault_version = "1.0.1"
  key_pem       = "key.pem"
  cert_pem      = "cert.pem"

  # consul_version = "1.3.1"
  consul_bin          = "consul_1.3.1_linux_386.zip"
  consul_cluster_size = "${var.consul_cluster_size}"
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
 Due to the circular nature here of resources, Create the bucket
 using the private S3 module without policy and then create
 policy on top of that and add to instance_profile
 use -target to create the bucket first
--------------------------------------------------------------*/
module private_s3 {
  source      = "../terraform-aws-vault/modules/private-s3"
  bucket_name = "${var.my_bucket}"
}

/*--------------------------------------------------------------
You can add the cert, key and other install files like so

resource "aws_s3_bucket_object" "key_object" {
  bucket = "${var.my_bucket}"
  key    = "${var.install_dir}/${var.key_name}"
  source = "${var.key_file}"
  etag   = "${md5(file("${var.key_file}"))}"
}
--------------------------------------------------------------*/
/*--------------------------------------------------------------
Then add this policy to the instance role to allow access
Copy the provisioning/templates/s3-access-role.json.tpl from the
vault module to a local space and refefrence it here.
--------------------------------------------------------------*/

resource "aws_iam_role_policy" "s3-access" {
  name   = "s3-access-policy"
  role   = "${module.vault_cluster.cluster_server_role}"
  policy = "${data.template_file.s3_iam_policy.rendered}"
}

data "template_file" "s3_iam_policy" {
  template = "${file("s3-access-role.json.tpl")}"

  vars {
    s3-bucket-name = "${var.my_bucket}"
  }
}
