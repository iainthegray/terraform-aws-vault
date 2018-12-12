/*------------------------------------------------
Configuration variables to provision a private S3 bucket
------------------------------------------------*/
variable "bucket_name" {
  description = "The name of the S3 bucket. If this is to be created then it must be unique"
  type        = "string"
}
variable "create_bucket" {
  description = "a variable that defines if the S3 bucket should be created or not"
  type        = "string"
  default = false
}
variable "global_region" {
  description = "the region S3 bucket policies will be provisioned into"
  type        = "string"
}

variable "my_user" {
  description = "An IAM user that can access the S3 bucket"
  type        = "string"
}

variable "create_user_access" {
  description = "Should the S3 bucket have IAM user access"
  type        = "string"
  default = true
}

variable "cluster_server_role" {
  description = "the role the S3 access policies should be attached to"
  type        = "string"
}
