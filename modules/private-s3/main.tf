/*--------------------------------------------------------------
An S3 bucket that is private to your instances for installs
--------------------------------------------------------------*/

resource "aws_s3_bucket" "install_bucket" {
  count  = "${(var.create_bucket ? 1 : 0)}"
  bucket = "${var.bucket_name}"
  acl    = "private"

  tags {
    Name = "${var.bucket_name}"
  }
}

/*--------------------------------------------------------------
S3 IAM Role and Policy
--------------------------------------------------------------*/
resource "aws_iam_role_policy" "s3-access" {
  name   = "s3-access-${var.global_region}"
  role   = "${var.cluster_server_role}"
  policy = "${data.template_file.s3_iam_policy.rendered}"
}

data "template_file" "s3_iam_policy" {
  template = "${file("${path.module}/provisioning/templates/s3-access-role.json.tpl")}"

  vars {
    s3-bucket-name = "${var.bucket_name}"
  }
}

/*--------------------------------------------------------------
IAM user access to S3
If var.create_user_access is false then this will not be created
--------------------------------------------------------------*/
resource "aws_iam_user_policy" "desktop-access" {
  count  = "${var.create_user_access ? 1 : 0}"
  name   = "desk-access"
  user   = "${var.my_user}"
  policy = "${data.template_file.s3_iam_policy.rendered}"
}
