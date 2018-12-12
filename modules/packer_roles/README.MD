# packer_roles

This is a simple module to create a role and 2 policies attached to allow [Packer](https://www.packer.io/intro/) to create images and also be able to get provisioning files from a private S3 bucket.

## Usage

Once this terraform has been run simply add the "iam_instance_profile" line to your packer json where the name is the same as the variable var.role_name:
e.g.
```hcl

....
"builders": [
  {
    "type": "amazon-ebs",
    "region": "eu-west-1",
    "source_ami": "{{user `source_ami`}}",
    "instance_type": "t2.micro",
    "ssh_username": "ubuntu",
    "iam_instance_profile": "Packer-S3-Access",
    "communicator": "ssh",
  }
]
....
```

## Example
```hcl
module "packer_roles" {
  # This source should be the tag for this module if pulling from git
  source          = "../modules/packer_roles"
  s3_bucket_name  = "${var.s3_bucket}"
  account_id      = "${var.account_id}"
  role_name       = "${var.role_name}"
  ec2_policy_name = "${var.ec2_pol_name}"
  s3_policy_name  = "${var.s3_pol_name}"
  region          = "${var.aws_region}"
}
```
