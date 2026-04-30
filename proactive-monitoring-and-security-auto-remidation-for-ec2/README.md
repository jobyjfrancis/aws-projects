# Project overview

## Situation:

CloudGuard, a financial services company, recently experienced a security breach because their operations team didn't detect unusual system behavior until it was too late. The incident resulted in significant downtime and potential data exposure. Management has prioritized implementing proactive monitoring and automated remediation to prevent similar incidents.

## Solution:

A comprehensive monitoring and auto-remediation system using AWS CloudWatch, Lambda, and GuardDuty that automatically detects and responds to performance issues and security threats across development and production environments.

## Steps to be performed:

The project contains the following steps:

* Architecture diagram
* Configure EC2 Environments (Dev and Prod)
* Implement Custom CloudWatch Monitoring
* Create Automated Remediation with Lambda
* Enable GuardDuty and Security Incident Response

## Services Used:

* Amazon EC2: Virtual servers to simulate development and production environments
* Amazon CloudWatch: Monitoring service for metrics, alarms, and automated responses
* AWS Lambda: Serverless compute service for running auto-remediation code
* AWS GuardDuty: Intelligent threat detection service
* AWS IAM: Identity and Access Management service for controlling permissions

# Actions performed:

## Architecture diagram

[To-Do]

## Setup of EC2 instances for Dev and Prod environments

1. Create two EC2 instances with the following parameters:

EC2 instance 1 (Dev):
--------------------
* Name: dev-server
* Additonal tag: Key: Environment, Value: Development
* Amazon Machine Image (AMI): Amazon Linux 2023
* Instance type: t3.micro
* Key pair: <SSH key pair>
* Network settings: Allow SSH traffic from your IP
    -> Create security group: 
        -> Rule: SSH from My IP
* Configure storage: Default (8 GB gp3)

EC2 instance 2 (Prod):
---------------------
* Name: prod-server
* Additonal tag: Key: Environment, Value: Production
* Amazon Machine Image (AMI): Amazon Linux 2023
* Instance type: t3.micro
* Key pair: <SSH key pair>
* Network settings: Allow SSH traffic from your IP
    -> Create security group: 
        -> Rule: SSH from My IP
* Configure storage: Default (8 GB gp3)

## Configuration of EC2 instances with tools

In this stage, we will configure both `dev` and `prod` ec2 instances with specific tools which can be used to simulate/generate real world performance issues.

The `dev` server will be installed with `stress` tool to generate CPU load and `prod` server will be installed with `util-linux` (to use `falloc`) to consume excessive disk space.

1. SSH into the `dev-server` instance and install `stress` tool as per below:

2. SSH into the `prod-server` instance and install `util-linux` tool as per below:

## Install CloudWatch agent for custom metrics

The default EC2 metrics available in CloudWatch are limited to basic system data like CPU utilization. By installing the CloudWatch agent, we can monitor critical metrics like memory usage, disk space, and detailed system performance data that are essential for comprehensive monitoring.

Dev instance
------------
1. SSH into the `dev-server` and install cloudwatch agent as per shown below:

2. Create the amazon cloudwatch agent configuration file under `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json` (use the confiuration defined in the file `amazon-cloudwatch-agent-dev-config.json` in this repository)

3. Apply the configuration and restart the agent as per below:

```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```
Prod instance
------------
1. SSH into the `prod-server` and install cloudwatch agent as per shown below:

2. Create the amazon cloudwatch agent configuration file under `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json` (use the confiuration defined in the file `amazon-cloudwatch-agent-prod-config.json` in this repository)

3. Apply the configuration and restart the agent as per below:

```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

## Set Up CloudWatch Alarms and Lambda Auto-Response

### CloudWatch Alarms for EC2 Monitoring

Setup a High usage CPU alarm
----------------------------
1. Create an alarm under Cloudwatch -> Alarms with the following configuration:
    * Select metric -> EC2 -> Per-Instance Metrics
    * Search bar: "CPUUtilization"
    * Find the Dev instance in the list
    * Select `CPUUtilization` metric for your instance
    * Click on `Select metric`
    
    Configure the metrics:
    * Statistic: average
    * Period: 1 minute

    Conditions:
    * Threshold type: Static
    * Whenever CPUUtilization is: Greater than/equal to
    * Threshold value: 85

    Actions:
    * Alarm state trigger", select "In alarm"
    * Send a notification to the following SNS topic: Create new topic
    * Topic name: EC2_Alarms
    * Email endpoints: <your email address>
    * Click on `Create topic` ->  this would send an email with AWS verification link - confirm subscription to receive notifications

    Name and description:
    * Alarm name: DevInstance-HighCPU
    * Alarm description: Alerts when CPU usage exceeds 85% for 1 minute

Setup a High Disk usage alarm
-----------------------------
Before setting up Cloudwatch alarm for disk space usage, we need to set the following:

* Appropriate IAM permissions for the EC2 instance so that CWagent can send logs

1. If we check the `Prod` instance cloudwatch logs, it would show the following which indicates lack of proper IAM permissions:

```
<paste logs in here>
```

a) To fix the issue, create an appropriate IAM role as per below:

* IAM -> Roles -> Create Role
* Trusted entity type: AWS service
* Use case: EC2
* Permissions policy: `CloudWatchAgentServerPolicy` managed policy
* Role name: EC2CloudWatchAgentRole

b) Attach the new IAM role to the `Prod` EC2 instance

* "Actions" > "Security" > "Modify IAM Role" -> Select role `CloudWatchAgentServerPolicy` -> Update IAM role

2. Create an alarm under Cloudwatch -> Alarms with the following configuration:
    * Select metric -> CWAgent -> device, fstype, host, path
    * Search bar: "disk_used_percent"
    * Find the `Prod` instance in the list
    * Select `disk_used_percent` metric for your instance
    * Click on `Select metric`
    
    Configure the metrics:
    * Statistic: average
    * Period: 1 minute

    Conditions:
    * Threshold type: Static
    * Whenever disk_used_percent is: Greater than/equal to
    * Threshold value: 80

    Actions:
    * Alarm state trigger", select "In alarm"
    * Send a notification to the following SNS topic: `Select an existing SNS topic`
    * Topic name: EC2_Alarms
    
    Name and description:
    * Alarm name: ProdInstance-LowDisk
    * Alarm description: Alerts when disk usage exceeds 80% for 1 minute

### Setup Lambda for an automatic response

Here we setup a Lambda function which executes in response to the high CPU or disk usage alerts from Dev or Prod instance

1. Lambda console -> Create function -> Author from scratch
    * Function name: "EC2-AutoRemediation"
    * Runtime: "Python 3.10" 
    * Architecture: x86_64
    * Permissions -> Change default execution role: Create a new role with basic Lambda permissions
    * Click -> Create function 

2. After function creation, go to `configuration` tab
    * Permissions: click on `EC2-AutoRemediation-role-xxxx`
        * In the new IAM console -> attach policies
        * Search for `AmazonEC2ReadOnlyAccess` and attach it
    * Add permissions -> Inline policy -> JSON tab
    * Paste the following policy
            ```
                        {
                "Version": "2012-10-17",
                "Statement": [
                    {
                    "Effect": "Allow",
                    "Action": "ec2:CreateTags",
                    "Resource": "arn:aws:ec2:*:*:instance/*"
                    }
                ]
                }
            ```
    * Click on Next -> Policy name `EC2TaggingPermissions` -> Create policy

    ```
    The above permissions are required by Lambda function to read EC2 instance information and add tags to track issues. We're following the principle of least privilege by only granting the specific permissions needed.
    ```
3. Return to Lambda function tab -> delete template code and paste the code in file `ec2-auto-remediation.py` -> deploy

```
This Lambda function code receives alarm notifications from SNS, identifies the affected EC2 instance and issue type, and adds an "Issue" tag with the value "HighCPU" or "LowDisk". In a production environment, you could extend this to take automatic remediation actions like restarting services or scaling resources.
```
```
For simplicity, our Lambda function won't take any actual remediation action here, but instead add a tag to the respective EC2 instance based on the alert. In actual production environments we can take actions like restarting an EC2 instance, auto-scaling instances to manage the traffic etc.
```
### Connecting Lambda to SNS

1. Go to `SNS console -> Topics -> EC2_Alarm`

2. Create subscription
    * Protocol: AWS Lambda
    * Endpoint: EC2-AutoRemediation

```
SNS acts as the messaging backbone, delivering CloudWatch alarm notifications to both human operators (via email) and automated systems (via Lambda). This helps ensure both automated and manual response can happen in parallel.
```

## Testing the monitoring system, alarms and responses

Here, we would introduce CPU performance issue in the `dev` server and disk space issue in the `prod` server using the tools we installed in these servers - `stress` and `falloc` and watch how Cloudwatch monitoring and alarms work. We would also check how the Lambda function respond to these alerts.

### Development Environment

1. SSH into the `dev` server and run the following command to generate CPU load

```
sudo stress --cpu 8 --timeout 600
```
2. In AWS -> CloudWatch console -> Alarms, click on `DevInstance-HighCPU` and monitor the `CPUUtilization`. It should transition to `In Alarm` in a few minutes.

3. Once the alarm state is `In Alarm`, check your email for the AWS notification

4. Check AWS Lambda -> ClouWatch logs for EC2-AutoRemediation function and it should show an invocation

5. Go to the EC2 instance -> `dev-server` -> Tags and could confirm that tags have been created

### Production Environment

1. SSH into the `prod` server and run the following command to increase disk usage

```
fallocate -l 6G /home/ec2-user/fakefile
```
```
This command creates a 6GB file, which on a standard t3.micro instance with an 8GB volume will push disk usage well above our 80% threshold.
```
2. In AWS -> CloudWatch console -> Alarms, click on `ProdInstance-LowDisk` and monitor the `disk_used_percent`. It should transition to `In Alarm` in a few minutes.

3. Once the alarm state is `In Alarm`, check your email for the AWS notification and Lambda function logs for function invocation

4. Go to the EC2 instance -> `prod-server` -> Tags and could confirm that tags have been created

## Setting Up AWS GuardDuty and Simulating Security Threats for CloudGuard

1. Go to GuardDuty console -> Getting Started

2. Review the "Service role permissions" section

3. Click "Enable GuardDuty"

### Preparing Your Dev Environment and Simulate security threat

1. Reboot the `dev-server`

2. Install the network mapper tool (nmap)

```
sudo yum install nmap -y
```
3. From the `dev-server`, perform an aggressive port scan against `prod-server`

```
sudo nmap -Pn -p 1-1000 -T4 -A [prod-server-IP]
```
`Pn`: Skip host discovery and assume the target is online
`p 1-1000`: Scan ports 1-1000
`T4`: Use aggressive timing template (faster scan)
`A`: Enable OS detection, version detection, script scanning, and traceroute

This scan simulates a reconnaissance activity that an attacker might perform before attempting to exploit vulnerabilities.

4. Wait for GuardDuty to detect and report the security event. GuardDuty needs some time to analyze logs and identify patterns

5. Navigate to the GuardDuty console and click on "Findings" in the left navigation pane. This would list the security findings

# Terraform Code

The terraform configuration for the project can be found at [terraform](./terraform)






    





