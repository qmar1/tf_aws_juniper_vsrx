**SSM configuration needed for running the vSRX module**

`Get the vSRX impage id (AMI) for the region you want to deploy`
**change profile to your profile and region to the region you want**

```sh
$ aws ec2 describe-images --owners 679593333241 --filters "Name=name,Values=junos-vsrx3-x86-64-20.3R*-consec*"  --region us-east-1 --profile kumar | jq '.Images[].Description,.Images[].ImageId'
"junos-vsrx3-x86-64-20.3R2.9-consec4--prod"
"ami-095486325dc03c306"
```
`Put the ami_id into ssm parameter store in the region you are deploying the vSRX`
**change region to the same where vSRX is being deployed and change --profile to what you have configured on aws configure/cli**

```sh
aws ssm put-parameter \
    --name "vsrx-usw2-20.3R2.9" \
    --value "ami-0bba6f3d8f4b4c027" \
    --type String \
    --data-type "aws:ec2:image" \
    --region us-east-1 \
    --profile kumar
```
**Verifying ssm parameter store**
```sh
$ aws ssm get-parameters --names vsrx-usw1-20.3R2.9 --profile kumar --region us-west-1
{
    "Parameters": [
        {
            "Name": "vsrx-usw1-20.3R2.9",
            "Type": "String",
            "Value": "ami-0de75af703f138a2a",
            "Version": 1,
            "LastModifiedDate": "2022-04-11T20:01:27.809000+05:30",
            "ARN": "arn:aws:ssm:us-west-1:934144586562:parameter/vsrx-usw1-20.3R2.9",
            "DataType": "aws:ec2:image"
        }
    ],
    "InvalidParameters": []
}

```
