resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set = [
  {
    name  = "clusterName"
    value = var.cluster_name
  },

    {
    name  = "serviceAccount.create"
    value = "true"
  },

  {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  },

  {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_irsa_role
  }
  ]
}

resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "47.6.1"

  namespace        = "prometheus-stack"
  create_namespace = true

  values = [
    "${file("values-prometheus.yaml")}"
  ]

  # Ensure StorageClass and ALB controller exist before deploying
  depends_on = [
    kubernetes_storage_class_v1.gp3,
    helm_release.alb_controller
  ]
}

resource "helm_release" "blackbox" {
  name       = "blackbox-exporter"
  namespace  = "monitoring"
  create_namespace = true
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = "8.8.0"

  values = [
    file("${path.module}/values-blackbox.yaml")
  ]
}