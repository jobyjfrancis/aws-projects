For the Prod server, the Lambda function executed in response to the alarm, but failed to tag the instance.

The issue was that lambda function timeout was set to 3 sec ==> increased it to 1 minute