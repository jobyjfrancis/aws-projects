https://docs.aws.amazon.com/codepipeline/latest/userguide/how-to-custom-role.html#how-to-custom-role-policy

# Role name: AWSCodePipelineServiceRole-ap-southeast-2-globalmart-pipeline

****************** = Account ID

# Trust policy:

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CodePipelineTrustPolicy",
            "Effect": "Allow",
            "Principal": {
                "Service": "codepipeline.amazonaws.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "******************"
                }
            }
        }
    ]
}

##########################################################################
## Permissions / Policies
-------------------------
# Policy 1: AWSCodePipelineServiceRole-ap-southeast-2-globalmart-pipeline

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
                    "aws:ResourceAccount": "******************"
                }
            }
        },
        {
            "Sid": "AllowS3ObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-southeast-2-*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceAccount": "******************"
                }
            }
        }
    ]
}

# Policy 2: CodePipeline-CodeDeploy-ap-southeast-2-globalmart-pipeline

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetDeployment",
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:ListDeployments",
                "codedeploy:ListDeploymentGroups",
                "codedeploy:GetDeploymentGroup"
            ],
            "Resource": [
                "arn:aws:codedeploy:*:******************:application:GlobalMart-Catalog",
                "arn:aws:codedeploy:*:******************:deploymentgroup:GlobalMart-Catalog/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:GetDeploymentConfig"
            ],
            "Resource": [
                "arn:aws:codedeploy:*:******************:deploymentconfig:CodeDeployDefault.OneAtATime"
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

# Policy 3: CodePipeline-Commands-ap-southeast-2-globalmart-pipeline

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
                "arn:aws:logs:ap-southeast-2:******************:log-group:/aws/codepipeline/globalmart-pipeline",
                "arn:aws:logs:ap-southeast-2:******************:log-group:/aws/codepipeline/globalmart-pipeline:log-stream:*"
            ]
        }
    ]
}