/*------------------------------------------------
Configuration variables to provision a private S3 bucket
------------------------------------------------*/
variable "bucket_name" {
  description = "The name of the S3 bucket. If this is to be created then it must be unique"
  type        = "string"
}
