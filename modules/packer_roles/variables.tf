/*------------------------------------------------
Configuration variables with defaults
------------------------------------------------*/
variable "role_name" {
  description = "The name of the packer role"
  type        = "string"
  default     = "Packer-AMI-Create-Role"
}

variable "ec2_pol_name" {
  description = "The name of the packer EC2 policy"
  type        = "string"
  default     = "packer-ec2-policy"
}

variable "s3_pol_name" {
  description = "The name of the packer S3 policy"
  type        = "string"
  default     = "packer-s3-policy"
}

/*------------------------------------------------
Configuration variables that need to be supplied
------------------------------------------------*/
variable "account_id" {
  description = "The account number of the AWS account"
  type        = "string"
}

variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = "string"
}

variable "aws_region" {
  description = "the region the roles will be deployed into"
  type        = "string"
}
