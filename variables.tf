variable "name" {
  description = <<-EOT
      Name of the Kubernetes cluster.
    EOT
  type        = string
}

variable "kubernetes_version" {
  description = <<-EOT
      Version of Kubernetes control plane to deploy.
    EOT
  type        = string
}

variable "vpc_cidr" {
  description = <<-EOT
      CIDR for vpc
    EOT
  type        = string
}

variable "private_subnets" {
  description = <<-EOT
      Private subnet CIDRs
    EOT
  type        = list
}

variable "public_subnets" {
  description = <<-EOT
        Public subnet CIDRs
    EOT
  type        = list
}

variable "worker_instance_type" {
  description = <<-EOT
    The EC2 Instance type to create for workers
  EOT
  default = "t2.small"
}

variable "max_workers" {
  description = <<-EOT
    The maximum number of instances to maintain in the worker pool
  EOT
  default = 10
}

variable "desired_capacity" {
  description = <<-EOT
    The number of instances to launch and maintain in the cluster
  EOT
  default = 1
}

variable "map_roles" {
  description = <<-EOT
    List of role mapping data structures to configure the AWS IAM Authenticator.
    See: https://github.com/kubernetes-sigs/aws-iam-authenticator#full-configuration-format
    [{
      rolearn = "arn:aws:iam::000000000000:role/KubernetesAdmin"
      username = "kubernetes-admin"
      groups = ["system:masters"]
    }]
  EOT
  type        = list
  default     = []
}