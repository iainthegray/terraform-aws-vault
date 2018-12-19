terraform {
  required_version = ">= 0.11.10"
}

provider "aws" {
  region = "${var.aws_region}"
}

/*------------------------------------------------------------------------------
The module simply takes 2 variables and creates a role with policies to allow Packer
to create AMIs and acces a private bucket.
------------------------------------------------------------------------------*/
resource "aws_iam_role" "packer_access" {
  name               = "${var.role_name}"
  path               = "/"
  assume_role_policy = "${file("${path.module}/provisioning/files/packer-role.json")}"
}

resource "aws_iam_role_policy" "packer_ec2" {
  name   = "${var.ec2_pol_name}"
  role   = "${aws_iam_role.packer_access.id}"
  policy = "${data.template_file.packer_ec2_iam_policy.rendered}"
}

resource "aws_iam_role_policy" "packer_s3" {
  name   = "${var.s3_pol_name}"
  role   = "${aws_iam_role.packer_access.id}"
  policy = "${data.template_file.packer_s3_iam_policy.rendered}"
}

data "template_file" "packer_ec2_iam_policy" {
  template = "${file("${path.module}/provisioning/templates/packer_ec2_policy.json.tpl")}"

  vars {
    account_id = "${var.bucket_name}"
    role_name  = "${var.role_name}"
  }
}

data "template_file" "packer_s3_iam_policy" {
  template = "${file("${path.module}/provisioning/templates/packer_s3_policy.json.tpl")}"

  vars {
    s3-bucket-name = "${var.account_id}"
  }
}
