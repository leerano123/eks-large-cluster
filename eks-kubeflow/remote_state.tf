terraform {
  backend "s3" {
    bucket = "backend-ralph-bucket3452"
    key    = "eks/eks-cluster/state"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = { 
    bucket = "backend-ralph-bucket3452"
    key    = "eks/eks-infrastructure/state"
    region = "us-east-1"
  }
}