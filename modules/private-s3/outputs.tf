output "bucket_arn" {
  description = "The arn of the bucket"
  value       = "${aws_s3_bucket.install_bucket.arn}"
}
output "bucket_id" {
  description = "The id of the bucket"
  value       = "${aws_s3_bucket.install_bucket.id}"
}
