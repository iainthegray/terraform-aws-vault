/*--------------------------------------------------------------
An S3 bucket that is private to your instances for installs
--------------------------------------------------------------*/

resource "aws_s3_bucket" "install_bucket" {
  bucket = "${var.bucket_name}"
  acl    = "private"
  tags {
    Name = "${var.bucket_name}"
  }
}
