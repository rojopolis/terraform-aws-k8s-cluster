
data "aws_availability_zones" "available" {}

data "aws_region" "current" {}


# Create VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.17.0"

  name                 = "${var.name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }
}

locals {
  node_role_map = [{
      rolearn = "${aws_iam_role.workers.arn}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = ["system:nodes"]
    }]
  map_roles = concat(local.node_role_map, var.map_roles)
}

# Create EKS cluster
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = var.name
  subnets      = concat(module.vpc.private_subnets,module.vpc.public_subnets)
  vpc_id       = module.vpc.vpc_id
  #map_roles    = local.map_roles

  worker_groups = [
    {
      instance_type = var.worker_instance_type
      asg_max_size  = var.max_workers
    }
  ]
}

# Create SSH Keypair
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.this.public_key_openssh
}

# AMI ID for the EKS optimized image for this EKS version in this region.
# https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html
data "aws_ssm_parameter" "worker_ami" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/image_id"
}

# Create security group for workers.
resource "aws_security_group" "allow_ssh" {
  name_prefix = "${var.name}-allow-ssh"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "workers_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workers" {
  name_prefix           = "${var.name}"
  assume_role_policy    = "${data.aws_iam_policy_document.workers_assume_role_policy.json}"
  force_detach_policies = true
}

resource "aws_iam_instance_profile" "workers" {
  name_prefix = "${var.name}"
  role        = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_policy" "workers_alb" {
  name        = "ALBIngressControllerIAMPolicy-${var.name}"
  path        = "/"
  description = "Allow EKS nodes to create and configure ALB resources"

  policy = templatefile("${path.module}/alb_policy.json", {})
}

resource "aws_iam_role_policy_attachment" "workers_alb" {
  policy_arn = aws_iam_policy.workers_alb.arn
  role       = aws_iam_role.workers.name
}

resource "aws_iam_policy" "workers_route53" {
  name        = "ExternalDNSControllerIAMPolicy-${var.name}"
  path        = "/"
  description = "Allow EKS nodes to create and configure DNS resources"

  policy = templatefile("${path.module}/route53_policy.json", {})
}

resource "aws_iam_role_policy_attachment" "workers_route53" {
  policy_arn = aws_iam_policy.workers_route53.arn
  role       = aws_iam_role.workers.name
}

