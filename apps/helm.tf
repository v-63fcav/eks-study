resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/values/values-alb-controller.yaml", {
      cluster_name  = var.cluster_name
      alb_irsa_role = var.alb_irsa_role
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "69.3.1"
  namespace        = "monitoring"
  create_namespace = true

  values = [file("${path.module}/values/values-kube-prometheus-stack.yaml")]

  # CRDs can be large; increase timeout for first install
  timeout = 600

  depends_on = [kubernetes_storage_class_v1.gp3]
}
