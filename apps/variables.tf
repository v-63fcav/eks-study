variable "aws_region" {
  default     = "us-east-2"
  description = "AWS region"
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "description"
}

variable "kube_host" {}
variable "kube_ca" {}
variable "alb_irsa_role" {}

# Read from infra remote state
locals {
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  adot_irsa_role   = data.terraform_remote_state.infra.outputs.adot_irsa_role
}
