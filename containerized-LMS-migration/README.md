# Project overview

## Situation:

Crown EduTech is an organisation that provides technical online learning for users around the world. They have a learning management system (LMS) that is currently hosted on-premises. Since they are expecting growth and more users in their Platform in future, they wanted to move to a cloud solution that provides scalability, security and performance. The DevOps engineers at Crown EduTech have decided to migrate from on-premises to a containerized AWS application.

## Solution:

A containerized LMS frontend on AWS ECS Fargate with monitoring capabilities. This project demonstrates how AWS container services work together and explore basic troubleshooting skills for common misconfigurations.

## Steps to be performed:

The project contains the following steps:

* Setting up the AWS environment for containerized applications
* Container image preparation for the LMS frontend
* Deploying the LMS frontend on ECS Fargate
* Comprehensive troubleshooting of container issues in ECS
* Resolving ALB configuration issues
* Correcting security group misconfigurations

## Services Used
* Amazon ECS with Fargate: Serverless compute engine for containers
* Application Load Balancer (ALB): Routes HTTP/HTTPS traffic to containers
* Amazon CloudWatch: Monitoring and observability for logs and metrics
* AWS IAM: Identity and access management for AWS resources
* Amazon ECR: Container registry for managing and deploying images
* AWS Security Groups: Virtual firewalls controlling network traffic

# Actions:

## Setup of AWS environment

1. Create a dedicated VPC for hosting our containerised application in Amazon ECS with the following options:
    * `Name`: EduTech-VPC
    * `Availability Zones`: 2
    * `Number of public subnets`: 2
    * `Number of private subnet`s: 0 (simplified for this implementation)
    * `NAT Gateways`: None (cost optimization)
    * `VPC Endpoints`: None

![alt text](images/image1.png)
![alt text](images/image2.png)
![alt text](images/image3.png)

![alt text](images/image4.png)

2. Create the following security groups for Application Load Balancer (ALB) and container with relevant inbound and outbound rules
    * `EduTech-ALB-SG`
    * `EduTech-Container-SG`

![alt text](images/image5.png)
![alt text](images/image6.png)

![alt text](images/image7.png)




