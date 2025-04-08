terraform {
  backend "s3" {
    bucket         = "drissahd-terraform-state-file"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
