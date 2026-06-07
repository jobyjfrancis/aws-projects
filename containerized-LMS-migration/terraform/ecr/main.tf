provider "aws" {
  region = var.aws_region
}

variable "aws_region" {}

resource "aws_ecr_repository" "edutech_lms_frontend" {
  name                 = "edutech-lms-frontend"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "edutech-lms-frontend"
  }
}