variable "aws_region" {}
variable "cidr_ipv4" {}
variable "keypair_name" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "dev_server_sg" {
  name        = "dev-server-sg"
  description = "Security group for dev server - SSH only"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "local_file" "cloudwatch_dev_config" {
  filename = "${path.module}/../amazon-cloudwatch-agent-dev-config.json"
}

# Create an EC2 instance for development environment
resource "aws_instance" "dev_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.dev_server_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y stress
              sudo yum install amazon-cloudwatch-agent -y

              cat > /tmp/cloudwatch-config.json <<'CONFIG'
              ${data.local_file.cloudwatch_dev_config.content}
              CONFIG
              sudo mv /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json
              EOF

  tags = {
    Name        = "dev-server"
    Environment = "Dev"
  }
}

resource "aws_security_group" "prod_server_sg" {
  name        = "prod-server-sg"
  description = "Security group for prod server - SSH only"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "local_file" "cloudwatch_prod_config" {
  filename = "${path.module}/../amazon-cloudwatch-agent-prod-config.json"
}

# Create an EC2 instance for production environment
resource "aws_instance" "prod_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.prod_server_sg.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo yum install -y util-linux
                sudo yum install amazon-cloudwatch-agent -y

                cat > /tmp/cloudwatch-config.json <<'CONFIG'
                ${data.local_file.cloudwatch_prod_config.content}
                CONFIG
                sudo mv /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json
                sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json
                EOF

  tags = {
    Name        = "prod-server"
    Environment = "Prod"
  }
}


