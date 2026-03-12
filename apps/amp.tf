# Amazon Managed Prometheus Workspace
resource "aws_prometheus_workspace" "main" {
  alias = "eks-study-prometheus"
  tags = {
    Environment = "eks-study"
    ManagedBy   = "terraform"
    Project     = "eks-study"
  }
}
