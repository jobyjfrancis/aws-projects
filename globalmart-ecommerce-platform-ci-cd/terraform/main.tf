provider "aws" {
  region = var.aws_region
}

variable "aws_region" {}
variable "keypair_name" {}
variable "subnet_id" {}
variable "market_place_amazon_linux_ami_alias" {}

data "aws_subnet" "default_subnet" {
  id             = var.subnet_id
  default_for_az = true
}

resource "aws_security_group" "globalmart_web_sg" {
  name        = "Globalmart-SG"
  description = "Allow HTTP/HTTPS from anywhere and SSH from my IP"
  tags = {
    Name = "Globalmart-SG"
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

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.globalmart_web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.globalmart_web_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "GlobalMart-WebServer"

  instance_type          = "t3.micro"
  key_name               = var.keypair_name
  ami_ssm_parameter      = var.market_place_amazon_linux_ami_alias
  monitoring             = true
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.globalmart_web_sg.id]
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






