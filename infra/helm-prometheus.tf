resource "local_file" "kubeconfig" {
  content  = module.eks.kubeconfig
  filename = "${path.module}/kubeconfig_${var.cluster_name}"
  depends_on = [module.eks]
}

provider "kubernetes" {
  alias       = "generated"
  config_path = local_file.kubeconfig.filename
}


resource "kubernetes_namespace" "monitoring" {
  provider = kubernetes.generated
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  provider = helm.generated

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "48.0.0"

  values = [
    file("${path.module}/observability/prometheus.yaml")
  ]

  depends_on = [module.eks]
}
