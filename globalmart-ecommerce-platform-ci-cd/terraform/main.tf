provider "aws" {
  region = var.aws_region
}

variable "aws_region" {}
variable "keypair_name" {}
variable "market_place_amazon_linux_ami_alias" {}
variable "cidr_ipv4" {}
variable "github_username" {}
variable "github_repository" {}
variable "github_repo_branch" {}
#variable "github_oauth_token" {}

data "aws_caller_identity" "current" {}

# Required IAM Roles for EC2 and CodeDeploy
module "iam_ec2_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "GlobalMart-EC2-Role"
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

  name            = "GlobalMart-CodeDeploy-Role"
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

# Create required IAM policies for CodePipeline role
# S3 access policy
module "iam_policy_s3_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "CodePipeline-S3-ap-southeast-2-globalmart-pipeline"
  path        = "/"
  description = "S3 access policy for CodePipeline"

  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowS3BucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketVersioning",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-southeast-2-*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceAccount": "${data.aws_caller_identity.current.account_id}"
                }
            }
        },
        {
            "Sid": "AllowS3ObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-southeast-2-*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceAccount": "${data.aws_caller_identity.current.account_id}"
                }
            }
        }
    ]
  }
EOF
}

# CodeDeploy access policy
module "iam_policy_codedeploy_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "CodePipeline-CodeDeploy-ap-southeast-2-globalmart-pipeline"
  path        = "/"
  description = "CodeDeploy access policy for CodePipeline"

  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentGroup",
                "codedeploy:GetDeploymentConfig"
            ],
            "Resource": [
                "arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:application:GlobalMart-Catalog",
                "arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:deploymentgroup:GlobalMart-Catalog/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:GetDeploymentConfig"
            ],
            "Resource": [
                "arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:ListDeploymentConfigs"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
  }
EOF
}

# Create an IAM policy for CodePipeline to allow it to use Codebuild
module "iam_policy_codebuild_access_codepipeline" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "CodePipeline-CodeBuild-ap-southeast-2-globalmart-pipeline"
  path        = "/"
  description = "CodeBuild access policy for CodePipeline"

  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild",
                "codebuild:StopBuild"
            ],
            "Resource": [
                "arn:aws:codebuild:*:${data.aws_caller_identity.current.account_id}:project/globalmart-build"
            ]
        }
    ]
  }
EOF
}

# Cloudwatch logs access policy
module "iam_policy_cloudwatch_logs_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "CodePipeline-Commands-ap-southeast-2-globalmart-pipeline"
  path        = "/"
  description = "CloudWatch Logs access policy for CodePipeline"

  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-southeast-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/globalmart-pipeline",
                "arn:aws:logs:ap-southeast-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/globalmart-pipeline:log-stream:*"
            ]
        }
    ]
  }
EOF
}

# Create CodePipeline role and attach the necessary policies
module "iam_codepipeline_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "AWSCodePipelineServiceRole-ap-southeast-2-globalmart-pipeline"
  use_name_prefix = false

  trust_policy_permissions = {
    allowcodepipelineassume = {
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["codepipeline.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole"]
    }
  }

  policies = {
    CodePipeline-S3-ap-southeast-2-globalmart-pipeline         = module.iam_policy_s3_access.arn,
    CodePipeline-CodeDeploy-ap-southeast-2-globalmart-pipeline = module.iam_policy_codedeploy_access.arn,
    CodePipeline-CodeBuild-ap-southeast-2-globalmart-pipeline  = module.iam_policy_codebuild_access_codepipeline.arn,
    CodePipeline-Commands-ap-southeast-2-globalmart-pipeline   = module.iam_policy_cloudwatch_logs_access.arn
  }

  tags = {
    Project = "GlobalMart"
  }
}

# Create IAM policy for CodeBuild
module "iam_policy_codebuild_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "CodeBuild-ap-southeast-2-globalmart-pipeline"
  path        = "/"
  description = "CodeBuild access policy for S3 and CloudWatch Logs"

  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-southeast-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/globalmart-build",
                "arn:aws:logs:ap-southeast-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/globalmart-build:log-stream:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:GetBucketVersioning"
            ],
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-southeast-2-*",
                "arn:aws:s3:::codepipeline-ap-southeast-2-*/*"
            ]
        }
    ]
  }
EOF
}

# Create CodeBuild IAM role
module "iam_codebuild_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "GlobalMart-CodeBuild-Role"
  use_name_prefix = false

  trust_policy_permissions = {
    allowcodebuildassume = {
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["codebuild.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole"]
    }
  }

  policies = {
    CodeBuild-S3-ap-southeast-2-globalmart-pipeline = module.iam_policy_codebuild_access.arn
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
  service_role_arn      = module.iam_codedeploy_role.arn

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

# Create an S3 bucket for CodePipeline artifact storage
resource "aws_s3_bucket" "codepipeline_artifact_bucket" {
  bucket         = "codepipeline-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
  force_destroy  = true
  tags = {
    Project = "GlobalMart"
  }
}

# Create CodeBuild project
resource "aws_codebuild_project" "globalmart_build" {
  name         = "globalmart-build"
  service_role = module.iam_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 18
  build:
    commands:
      - echo "Installing dependencies..."
      - npm install
      - echo "Building application..."
      - npm run build
      - echo "Preparing artifact for CodeDeploy..."
      - mkdir -p /tmp/artifact
      - cp -r * /tmp/artifact/ || true
artifacts:
  files:
    - '**/*'
  discard-paths: no
    EOF
  }

  tags = {
    Project = "GlobalMart"
  }
}

# Create a CodeStar Connections connection to GitHub  
resource "aws_codestarconnections_connection" "github_connection" {
  name          = "GlobalMart-GitHub-Connection"
  provider_type = "GitHub"
}

# Create a CodePipeline pipeline that integrates with GitHub as the source and CodeDeploy as the deployment provider  
resource "aws_codepipeline" "globalmart_codepipeline" {
  name           = "GlobalMart-Pipeline"
  pipeline_type  = "V2"
  role_arn       = module.iam_codepipeline_role.arn
  execution_mode = "QUEUED"

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifact_bucket.bucket
    type     = "S3"
  }

  # stage {
  #   name = "Source"

  #   action {
  #     name             = "SourceAction"
  #     category         = "Source"
  #     owner            = "ThirdParty"
  #     provider         = "GitHub"
  #     version          = "1"
  #     output_artifacts = ["SourceOutput"]

  #     configuration = {
  #       Owner      = var.github_username
  #       Repo       = var.github_repository
  #       Branch     = var.github_repo_branch
  #       OAuthToken = var.github_oauth_token
  #     }
  #   }
  # }
  stage {
    name = "Source"

    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "${var.github_username}/${var.github_repository}"
        BranchName       = var.github_repo_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.globalmart_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.globalmart_codedeploy_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.globalmart_codedeploy_deployment_group.deployment_group_name
      }
    }
  }

  tags = {
    Project = "GlobalMart"
  }
}







