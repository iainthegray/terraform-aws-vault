terraform {
  required_version = ">= 0.11.10"
}

/*------------------------------------------------------------------------------
The Vault cluster is either built as var.vault_cluster_size instances or as a
var.vault_cluster_size[min|max|des] instance ASG depending on the use of the
var.use_asg boolean.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
 This is the instance build for the Vault infra without an ASG. This is
defined only if the variable var.use_asg = false (default)
------------------------------------------------------------------------------*/

resource "aws_instance" "vault-instance" {
  ami                         = "${var.ami_id}"
  count                       = "${(var.use_asg ? 0 : var.vault_cluster_size)}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.cluster_server.id}"
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  subnet_id                   = "${element(var.private_subnets, count.index)}"
  user_data                   = "${data.template_file.vault_user_data.rendered}"

  tags = {
    Name = "vault_server-${count.index}"
  }
}

/*------------------------------------------------------------------------------
 This is the instance build for the Consul infra. This is deliberately
not built inside an ASG (coz)
------------------------------------------------------------------------------*/

resource "aws_instance" "consul-instance" {
  ami                         = "${var.ami_id}"
  count                       = "${var.consul_cluster_size}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.cluster_server.id}"
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  user_data                   = "${data.template_file.consul_user_data.rendered}"
  subnet_id                   = "${element(var.private_subnets, count.index)}"

  tags = {
    Name               = "consul_server-${count.index}"
    CONSUL_CLUSTER_TAG = "${var.cluster_tag}"
  }
}

/*------------------------------------------------------------------------------
This is the configuration for the Vault ASG. This is defined only if the
variable var.use_asg = true
------------------------------------------------------------------------------*/

resource "aws_launch_configuration" "vault_instance_asg" {
  count                = "${(var.use_asg ? 1 : 0)}"
  name_prefix          = "${var.cluster_name}-"
  image_id             = "${var.ami_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster_server.id}"
  security_groups      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
}

resource "aws_autoscaling_group" "vault_asg" {
  count                = "${(var.use_asg ? 1 : 0)}"
  name_prefix          = "${var.cluster_name}"
  launch_configuration = "${aws_launch_configuration.vault_instance_asg.name}"
  availability_zones   = ["${var.availability_zones}"]
  vpc_zone_identifier  = ["${var.private_subnets}"]

  min_size             = "${var.vault_cluster_size}"
  max_size             = "${var.vault_cluster_size}"
  desired_capacity     = "${var.vault_cluster_size}"
  termination_policies = ["${var.termination_policies}"]

  health_check_type         = "EC2"
  health_check_grace_period = "${var.health_check_grace_period}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"

  enabled_metrics = ["${var.enabled_metrics}"]

  lifecycle {
    create_before_destroy = true
  }
}

/*------------------------------------------------------------------------------
This is the configuration for the ELB. This is defined only if the variable
var.use_elb = true
------------------------------------------------------------------------------*/
resource "aws_elb" "vault_elb" {
  count                       = "${(var.use_elb ? 1 : 0)}"
  name_prefix                 = "elb-"
  internal                    = true
  cross_zone_load_balancing   = "${var.cross_zone_load_balancing}"
  idle_timeout                = "${var.idle_timeout}"
  connection_draining         = "${var.connection_draining}"
  connection_draining_timeout = "${var.connection_draining_timeout}"
  subnets                     = ["${var.private_subnets}"]

  listener {
    lb_port           = "${var.lb_port}"
    lb_protocol       = "TCP"
    instance_port     = "${var.vault_api_port}"
    instance_protocol = "TCP"
  }

  health_check {
    target              = "${var.health_check_protocol}:${var.vault_api_port}${var.health_check_path}"
    interval            = "${var.health_check_interval}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    timeout             = "${var.health_check_timeout}"
  }
}

/*--------------------------------------------------------------
Vault Cluster Instance Security Group
--------------------------------------------------------------*/

resource "aws_security_group" "vault_cluster_int" {
  name        = "vault_cluster_int"
  description = "The SG for vault Servers Internal comms"
  vpc_id      = "${var.vpc_id}"
}

/*--------------------------------------------------------------
Vault Cluster Internal Security Group Rules
--------------------------------------------------------------*/

resource "aws_security_group_rule" "vault_cluster_allow_self_8300-8302_tcp" {
  type              = "ingress"
  from_port         = 8300
  to_port           = 8302
  protocol          = "tcp"
  self              = true
  description       = "Consul gossip protocol between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8301-8302_udp" {
  type              = "ingress"
  from_port         = 8301
  to_port           = 8302
  protocol          = "udp"
  self              = true
  description       = "Consul gossip protocol between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8200_tcp" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
  description       = "Vault API port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8500_tcp" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  self              = true
  description       = "Consul API port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_self_8600_tcp" {
  type              = "ingress"
  from_port         = 8600
  to_port           = 8600
  protocol          = "tcp"
  self              = true
  description       = "Consul DNS port between agents and servers"
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

resource "aws_security_group_rule" "vault_cluster_allow_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.vault_cluster_int.id}"
}

/*------------------------------------------------------------------------------
 This is the IAM profile setup for the cluster servers to allow the consul
 servers to join a cluster.
------------------------------------------------------------------------------*/
resource "aws_iam_instance_profile" "cluster_server" {
  name = "cluster-server-${var.cluster_name}"
  role = "${aws_iam_role.cluster_server.name}"
}

resource "aws_iam_role" "cluster_server" {
  name               = "cluster-server-${var.cluster_name}"
  path               = "/"
  assume_role_policy = "${file("${path.module}/provisioning/files/cluster-server-role.json")}"
}

resource "aws_iam_role_policy" "cluster_server" {
  name   = "cluster-server-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${file("${path.module}/provisioning/files/cluster-server-role-policy.json")}"
}

/*--------------------------------------------------------------
S3 IAM Role and Policy to allow access to the userdata install files
--------------------------------------------------------------*/
resource "aws_iam_role_policy" "s3-access" {
  name   = "s3-access-install-${var.cluster_name}"
  role   = "${aws_iam_role.cluster_server.id}"
  policy = "${data.template_file.s3_iam_policy.rendered}"
}

data "template_file" "s3_iam_policy" {
  template = "${file("${path.module}/provisioning/templates/s3-access-role.json.tpl")}"

  vars {
    s3-bucket-name = "${var.install_bucket}"
  }
}
/* This is the set up of the userdata template file for the install */
data "template_file" "vault_user_data" {
  template = "${file("${path.module}/provisioning/templates/vault_ud.tpl")}"

  vars {
    install_bucket = "${var.install_bucket}"
    vault_bin      = "${var.vault_bin}"
    key_pem        = "${var.key_pem}"
    cert_pem       = "${var.cert_pem}"
    consul_version = "${var.consul_version}"
    cluster_tag    = "${var.cluster_tag}"
    consul_cluster_size   = "${var.consul_cluster_size}"
  }
}
data "template_file" "consul_user_data" {
  template = "${file("${path.module}/provisioning/templates/consul_ud.tpl")}"

  vars {
    install_bucket = "${var.install_bucket}"
    consul_version = "${var.consul_version}"
    cluster_tag    = "${var.cluster_tag}"
    consul_cluster_size   = "${var.consul_cluster_size}"
  }
}
