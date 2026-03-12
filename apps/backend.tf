terraform {
  backend "s3" {
    bucket         = "ps-sl-state-bucket-cavi-2"
    key            = "terraform-apps.tfstate"
    region         = "us-east-2"
    encrypt        = true
  }
}

# Read outputs from infra module
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "ps-sl-state-bucket-cavi-2"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}
