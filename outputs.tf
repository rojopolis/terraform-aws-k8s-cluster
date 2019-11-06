
output "kubeconfig" {
  description = <<-EOT
    Content of a `kubeconfig` file that can be used to connect to this cluster
  EOT
  value = module.eks.kubeconfig
}

output "kubeconfig_filename" {
  description = <<-EOT
    The filename of the generated kubectl config.
  EOT
  value = module.eks.kubeconfig_filename
}

output "ssh_private_key" {
  description = <<-EOT
    Private key for SSH access to worker nodes.
  EOT
  value = tls_private_key.this.private_key_pem
  sensitive = true
}