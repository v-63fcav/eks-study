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
