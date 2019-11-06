variable cluster_name {}

provider "aws" {
  version = "~> 2.33"
}

module "k8s_cluster" {
  source = "../"

  name               = var.cluster_name
  kubernetes_version = "1.14"
  vpc_cidr           = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

output "kubeconfig" {
  value = module.k8s_cluster.kubeconfig
}

output "ssh_private_key" {
  value     = module.k8s_cluster.ssh_private_key
  sensitive = true
}