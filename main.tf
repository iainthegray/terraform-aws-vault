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
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  subnet_id                   = "${element(var.private_subnets, count.index)}"

  tags = {
    Name = "vault_server-${count.index}"
  }
}

/*------------------------------------------------------------------------------
This is the configuration for the Vault ASG. This is defined only if the
variable var.use_asg = true
------------------------------------------------------------------------------*/

resource "aws_launch_configuration" "vault_instance_asg" {
  count           = "${(var.use_asg ? 1 : 0)}"
  name_prefix     = "${var.cluster_name}-"
  image_id        = "${var.ami_id}"
  instance_type   = "${var.instance_type}"
  security_groups = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
}

resource "aws_autoscaling_group" "vault_asg" {
  count                = "${(var.use_asg ? 1 : 0)}"
  name_prefix          = "${var.cluster_name}"
  launch_configuration = "${aws_launch_configuration.vault_instance_asg.name}"
  availability_zones   = ["${var.availability_zones}"]
  vpc_zone_identifier  = ["${var.private_subnets}"]

  min_size             = "${var.vault_cluster_size_min}"
  max_size             = "${var.vault_cluster_size_max}"
  desired_capacity     = "${var.vault_cluster_size_des}"
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
 This is the instance build for the Consul infra. This is deliberately
not built inside an ASG (coz)
------------------------------------------------------------------------------*/

resource "aws_instance" "consul-instance" {
  ami                         = "${var.ami_id}"
  count                       = "${var.consul_cluster_size}"
  instance_type               = "${var.instance_type}"
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${concat(var.additional_sg_ids, list(aws_security_group.vault_cluster_int.id))}"]
  subnet_id                   = "${element(var.private_subnets, count.index)}"

  tags = {
    Name = "consul_server-${count.index}"
  }
}
