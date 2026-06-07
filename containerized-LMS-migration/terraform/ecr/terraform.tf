terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }

  backend "s3" {
    bucket = "aws-projects-tf-state-backend-v2"
    key    = "containerized-lms-migration/ecr/terraform.tfstate"
    region = "ap-southeast-2"
  }

  required_version = ">= 1.13"
}
