output "vault_cluster_instance_ids" {
  description = "list of instance IDs of the created vault cluster "
  value       = ["${aws_instance.vault-instance.*.id}"]
}

output "vault_cluster_instance_ips" {
  description = "list of ip addresses for the instances in the created vault cluster "
  value       = ["${aws_instance.vault-instance.*.private_ip}"]
}
