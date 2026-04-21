import boto3
import json

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))
    
    # Extract message from SNS
    message = json.loads(event['Records'][0]['Sns']['Message'])
    print("Alarm message: " + json.dumps(message))
    alarm_name = message['AlarmName']
    
    # Get instance ID from dimensions - handle both EC2 and CloudWatch Agent formats
    instance_id = None
    
    # Print dimensions to debug
    if 'Trigger' in message and 'Dimensions' in message['Trigger']:
        print("Dimensions: " + json.dumps(message['Trigger']['Dimensions']))
        
        for dimension in message['Trigger']['Dimensions']:
            # For native EC2 metrics
            if dimension['name'] == 'InstanceId':
                instance_id = dimension['value']
                print(f"Found InstanceId dimension: {instance_id}")
                break
            # For CloudWatch Agent metrics
            elif dimension['name'] == 'host':
                instance_id = dimension['value']
                print(f"Found host dimension: {instance_id}")
                
                # If instance_id looks like a hostname rather than an instance ID
                if instance_id and not instance_id.startswith('i-'):
                    try:
                        # Use EC2 describe_instances to find instance by private DNS name
                        ec2 = boto3.client('ec2')
                        response = ec2.describe_instances(
                            Filters=[
                                {
                                    'Name': 'private-dns-name',
                                    'Values': [instance_id]
                                }
                            ]
                        )
                        
                        # Extract instance ID if found
                        if response['Reservations'] and response['Reservations'][0]['Instances']:
                            instance_id = response['Reservations'][0]['Instances'][0]['InstanceId']
                            print(f"Converted hostname to instance ID: {instance_id}")
                    except Exception as e:
                        print(f"Error converting hostname to instance ID: {str(e)}")
                break

    if not instance_id:
        print("No instance ID found in alarm")
        return {
            'statusCode': 400,
            'body': json.dumps('No instance ID found in alarm dimensions')
        }

    print(f"Processing alarm {alarm_name} for instance {instance_id}")

    # Determine issue type
    issue_tag = None
    if "HighCPU" in alarm_name:
        issue_tag = "HighCPU"
    elif "LowDisk" in alarm_name:
        issue_tag = "LowDisk"
    else:
        print(f"Unknown alarm type: {alarm_name}")
        return {
            'statusCode': 400,
            'body': json.dumps(f'Unknown alarm type: {alarm_name}')
        }

    # Tag the instance
    try:
        ec2 = boto3.client('ec2')
        ec2.create_tags(
            Resources=[instance_id],
            Tags=[
                {
                    'Key': 'Issue',
                    'Value': issue_tag
                }
            ]
        )
        print(f"Tagged instance {instance_id} with Issue={issue_tag}")
    except Exception as e:
        print(f"Error tagging instance: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error tagging instance: {str(e)}')
        }

    # For demonstration purposes, we'll log the action but not actually stop instances
    # In production, you might implement actual remediation steps here
    print(f"Remediation action would be taken for {issue_tag} on {instance_id}")

    return {
        'statusCode': 200,
        'body': json.dumps(f'Successfully processed alarm {alarm_name}')
    }