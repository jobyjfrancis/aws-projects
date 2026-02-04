provider "aws" {
  region = var.aws_region
}

variable "aws_region" {}

resource "aws_iam_role" "edutech_ecs_service_role" {
  name = "EduTech-ECS-Service-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "edutech_ecs_service_role_policy" {
  role       = aws_iam_role.edutech_ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role" "edutech_ecs_task_role" {
  name = "EduTech-ECS-Task-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "edutech_ecs_task_role_policy_1" {
  role       = aws_iam_role.edutech_ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "edutech_ecs_task_role_policy_2" {
  role       = aws_iam_role.edutech_ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

data "aws_availability_zones" "available" {}

module "edutech_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = "EduTech-VPC"
  cidr = "10.0.0.0/16"

  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "EduTech-VPC"
  }
}

resource "aws_security_group" "edutech_alb_sg" {
  name        = "EduTech-ALB-SG"
  description = "Allow HTTP and HTTPS from anywhere"
  vpc_id      = module.edutech_vpc.vpc_id

  ingress {
    description      = "Allow HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTPS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EduTech-ALB-SG"
  }
}

resource "aws_security_group" "edutech_container_sg" {
  name        = "EduTech-Container-SG"
  description = "Allow port 3000 from ALB SG"
  vpc_id      = module.edutech_vpc.vpc_id

  ingress {
    description     = "Allow 3000 from ALB SG"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.edutech_alb_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "EduTech-Container-SG"
  }
}

resource "aws_ecr_repository" "edutech_lms_frontend" {
  name = "edutech-lms-frontend"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "edutech-lms-frontend"
  }
}

resource "aws_ecs_cluster" "edutech_lms_cluster" {
  name = "EduTech-LMS-Cluster"
  capacity_providers = ["FARGATE"]
  tags = {
    Name = "EduTech-LMS-Cluster"
  }
}



