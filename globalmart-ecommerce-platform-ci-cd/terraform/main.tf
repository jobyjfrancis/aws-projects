provider "aws" {
  region = var.aws_region
}

variable "aws_region" {}
variable "keypair_name" {}
variable "market_place_amazon_linux_ami_alias" {}
variable "cidr_ipv4" {}

# Required IAM Roles for EC2 and CodeDeploy
module "iam_ec2_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name = "GlobalMart-EC2-Role"
  use_name_prefix = false

  trust_policy_permissions = {
    allowec2assume = {
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole"]
    }
  }

  policies = {
    AmazonS3ReadOnlyAccess        = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    AmazonSSMManagedInstanceCore  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2RoleforAWSCodeDeploy = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
  }

  tags = {
    Project = "GlobalMart"
  }
}

module "iam_codedeploy_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name = "GlobalMart-CodeDeploy-Role"
  use_name_prefix = false

  trust_policy_permissions = {
    allowcodedeployassume = {
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["codedeploy.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole"]
    }
  }

  policies = {
    AWSCodeDeployRole = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  }

  tags = {
    Project = "GlobalMart"
  }
}

# Fetch the default subnet in the specified region and availability zone
data "aws_subnet" "default_subnet" {
  default_for_az    = true
  availability_zone = "${var.aws_region}a"
}

# Create a security group for the EC2 instance
resource "aws_security_group" "globalmart_web_sg" {
  name        = "Globalmart-SG"
  description = "Allow HTTP/HTTPS from anywhere and SSH from my IP"
  tags = {
    Name = "Globalmart-web-SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.globalmart_web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.globalmart_web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.globalmart_web_sg.id

  cidr_ipv4   = var.cidr_ipv4
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.globalmart_web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.globalmart_web_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}

# Create an IAM instance profile for the EC2 instance to allow it to assume the necessary role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "GlobalMart-EC2-Instance-Profile"
  role = module.iam_ec2_role.name
}

# Create an EC2 instance with the specified configuration
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "GlobalMart-WebServer"

  instance_type          = "t3.micro"
  key_name               = var.keypair_name
  ami_ssm_parameter      = var.market_place_amazon_linux_ami_alias
  monitoring             = true
  create_security_group  = false
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.globalmart_web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  user_data              = <<-EOF
  #!/bin/bash
  exec > /var/log/user-data.log 2>&1
  yum update -y

  # Install Node.js v16
  curl -sL https://rpm.nodesource.com/setup_16.x | bash -
  yum install -y nodejs

  # Install Nginx
  amazon-linux-extras install nginx1 -y
  systemctl start nginx
  systemctl enable nginx"
  EOF 

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create a CodeDeploy application
resource "aws_codedeploy_app" "globalmart_codedeploy_app" {
  compute_platform = "Server"
  name             = "GlobalMart-Catalog"
  tags = {
    Project = "GlobalMart"
  }
}

# Create a CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "globalmart_codedeploy_deployment_group" {
  app_name              = aws_codedeploy_app.globalmart_codedeploy_app.name
  deployment_group_name = "GlobalMart-Production"
  service_role_arn     = module.iam_codedeploy_role.arn

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "GlobalMart-WebServer"
    }
  }

  tags = {
    Project = "GlobalMart"
  }
}

# Create a CodePipeline pipeline that integrates with GitHub as the source and CodeDeploy as the deployment provider  
# resource "aws_codepipeline" "globalmart_codepipeline" {
#   name     = "GlobalMart-Pipeline"
#   role_arn = module.iam_codedeploy_role.arn

#   artifact_store {
#     location = aws_s3_bucket.codepipeline_artifacts.bucket
#     type     = "S3"
#   }

#   stage {
#     name = "Source"

#     action {
#       name             = "SourceAction"
#       category         = "Source"
#       owner            = "ThirdParty"
#       provider         = "GitHub"
#       version          = "1"
#       output_artifacts = ["SourceOutput"]

#       configuration = {
#         Owner  = "your-github-username"
#         Repo   = "your-repo-name"
#         Branch = "main"
#         OAuthToken = var.github_oauth_token
#       }
#     }
#   }

#   stage {
#     name = "Deploy"

#     action {
#       name             = "DeployAction"
#       category         = "Deploy"
#       owner            = "AWS"
#       provider         = "CodeDeploy"
#       version          = "1"
#       input_artifacts  = ["SourceOutput"]

#       configuration = {
#         ApplicationName     = aws_codedeploy_app.globalmart_codedeploy_app.name
#         DeploymentGroupName = aws_codedeploy_deployment_group.globalmart_codedeploy_deployment_group.deployment_group_name
#       }
#     }
#   }

#   tags = {
#     Project = "GlobalMart"
#   }
# }







