provider "helm" {
  version         = "~> 0.10"
  service_account = kubernetes_service_account.tiller.metadata[0].name
  kubernetes {
    config_path = module.eks.kubeconfig_filename
  }
}

resource "helm_release" "metrics_server" {
  # BUG:  This usually fails on initial apply
  # "Error: rpc error: code = Unknown desc = Could not get apiVersions from Kubernetes: unable to retrieve the complete list of server APIs: metrics.k8s.io/v1beta1: the server is currently unable to handle the request"
  # Applying again noramlly succeeds.
  depends_on = [kubernetes_cluster_role_binding.tiller]
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "stable"
  chart      = "metrics-server"
  version    = "2.8.8"

  set {
    # See https://github.com/kubernetes-incubator/metrics-server/issues/157#issuecomment-484047998
    name = "hostNetwork.enabled"
    value = "true"
  }
}

data "helm_repository" "incubator" {
  name = "incubator"
  url = "http://storage.googleapis.com/kubernetes-charts-incubator"
}

resource "helm_release" "aws_alb_ingress_controller" {
  name = "aws-alb-ingress-controller"
  namespace = "kube-system"
  repository = data.helm_repository.incubator.metadata[0].name
  chart = "aws-alb-ingress-controller"
  version = "0.1.11"

  set {
    name = "clusterName"
    value = module.eks.cluster_id
  }

  set {
    name = "awsRegion"
    value = data.aws_region.current.name
  }

  set {
    name = "awsVpcID"
    value = module.vpc.vpc_id
  }

  set {
    name = "rbac.serviceAccountName"
    value = "alb-ingress-controller"
  }
}

resource "helm_release" "external_dns" {
  name = "external-dns"
  namespace = "kube-system"
  repository = "stable"
  chart = "external-dns"
  version = "2.10.2"
}