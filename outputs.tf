output "vault_cluster_instance_ids" {
  description = "list of instance IDs of the created vault cluster "
  value       = ["${aws_instance.vault-instance.*.id}"]
}

output "vault_cluster_instance_ips" {
  description = "list of ip addresses for the instances in the created vault cluster "
  value       = ["${aws_instance.vault-instance.*.private_ip}"]
}

output "cluster_server_role" {
  description = "The role ID to attach policies to for the cluster instances"
  value       = "${aws_iam_role.cluster_server.id}"
}
output "consul_cluster_instance_ids" {
  description = "list of instance IDs of the created consul cluster "
  value       = ["${aws_instance.consul-instance.*.id}"]
}

output "consul_cluster_instance_ips" {
  description = "list of ip addresses for the instances in the created consul cluster "
  value       = ["${aws_instance.consul-instance.*.private_ip}"]
}
output "elb_dns" {
  description = "DNS name for the ELB if created"
  value = "${aws_elb.vault_elb.*.dns_name}"
}
