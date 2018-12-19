# Private S3 bucket module

This module is designed to optionally create an S3 bucket and assign access via a policy to a role. It optionally creates an S3 bucket based on the variable var.create_bucket or uses a pre-existing one. The purpose is to allow an S3 bucket to be accessed by instances that have the role so that they can download files from it for install.
It also optionally creates an IAM role that can be assigned to a IAM user for access to the same bucket.

## Usage
```hcl
module private_s3 {

  # This source should be the tag for this module if pulling from git
  source                        = "../terraform-aws-vault/modules/private-s3"
  global_region                 = "${var.global_region}"
  bucket_name                   = "bb-test-bucket-bucky"
  cluster_server_role           = "${module.vault_cluster.cluster_server_role}"
  # This variable is a boolean that determines whether to create the bucket or not.

  create_bucket                 = true

  # This variable is a boolean that determines whether to create an IAM policy that allows the user listed by the variable var.my_user also has access to the bucket.

  create_user_access           = false
  my_user                      = "bobby-bobbins"

}
```
