# AWS Execution Guide

This guide describes the current manual execution flow for the `AWS` implementation in this repository, starting from a local machine with `AWS CLI`, `Packer`, and repository access already available.

For lower-level lookup commands, see [AWS Commands Cheatsheet](commands-cheatsheet.md).

## 1. Discover Your Local AWS Profile

List the profiles available on your machine:

```bash
aws configure list-profiles
```

Choose the profile you want to use for this repository.

## 2. Log In To AWS

If your selected profile uses `AWS SSO`, log in with:

```bash
aws sso login --profile <profile>
```

Then verify access:

```bash
AWS_PROFILE=<profile> aws sts get-caller-identity
```

## 3. Prepare Reusable Environment Variables

You can keep the main values in a local `.envrc` or export them in your current shell:

```bash
export AWS_PROFILE="<profile>"
export AWS_REGION="<region>"
export AWS_VPC_ID="<vpc-id>"
export AWS_SUBNET_ID="<subnet-id>"
export AWS_KEY_NAME="<key-pair-name>"
export AWS_STACK_NAME="<stack-name>"
export PROJECT_TAG="<project-tag>"
```

Recommended lookup commands:

- profile list: [AWS Commands Cheatsheet](commands-cheatsheet.md#caller-identity)
- VPCs: [AWS Commands Cheatsheet](commands-cheatsheet.md#vpcs)
- subnets: [AWS Commands Cheatsheet](commands-cheatsheet.md#subnets)
- key pairs: [AWS Commands Cheatsheet](commands-cheatsheet.md#key-pairs)

Recommended example:

```bash
export AWS_STACK_NAME="penpot-cloud-image-aws-demo"
export PROJECT_TAG="penpot-cloud-image-aws"
export AWS_SSH_CIDR="203.0.113.10/32"
```

Replace `203.0.113.10/32` with the public IPv4 CIDR that should be allowed to reach the instance over SSH.

You can discover your current public IPv4 with:

```bash
curl -fsSL https://checkip.amazonaws.com
```

Then export it as a `/32` CIDR, for example:

```bash
export AWS_SSH_CIDR="203.0.113.10/32"
```

This example name is only intended for the current manual testing flow. It is not meant to define the final long-term stack naming convention.

## 4. Create Or Reuse An EC2 Key Pair

If you already have a key pair in the target region, list it with:

```bash
aws ec2 describe-key-pairs \
  --region "$AWS_REGION" \
  --query 'KeyPairs[].KeyName' \
  --output table
```

If you need to create one:

```bash
aws ec2 create-key-pair \
  --region "$AWS_REGION" \
  --key-name <key-pair-name> \
  --query 'KeyMaterial' \
  --output text > <key-pair-name>.pem
chmod 400 <key-pair-name>.pem
```

Then export the chosen key pair name:

```bash
export AWS_KEY_NAME="<key-pair-name>"
```

## 5. Build The AMI With Packer

Before creating resources, you can run the lightweight validation helper:

```bash
bash clouds/aws/scripts/validate.sh
```

This checks script syntax, validates the `Packer` template, and runs `CloudFormation` template validation without launching resources.

## 6. Build The AMI With Packer

Run the build from the repository root:

```bash
packer build \
  -var "aws_region=$AWS_REGION" \
  -var "project_tag=$PROJECT_TAG" \
  -var "vpc_id=$AWS_VPC_ID" \
  -var "subnet_id=$AWS_SUBNET_ID" \
  clouds/aws/packer/single-node.pkr.hcl
```

When the build succeeds, note the generated `AMI ID`.

## 7. Export The New AMI ID

Keep the latest built `AMI ID` in the current shell:

```bash
export AWS_AMI_ID="<ami-id>"
```

Example of the final `Packer` output:

```text
--> penpot-cloud-image-aws.amazon-ebs.al2023: AMIs were created:
eu-west-1: ami-0123456789abcdef0
```

In that case:

```bash
export AWS_AMI_ID="ami-0123456789abcdef0"
```

## 8. Launch The CloudFormation Stack

Create the stack using the AMI you just built:

```bash
aws cloudformation create-stack \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml \
  --parameters \
    ParameterKey=AmiId,ParameterValue="$AWS_AMI_ID" \
    ParameterKey=InstanceType,ParameterValue=t3.medium \
    ParameterKey=KeyName,ParameterValue="$AWS_KEY_NAME" \
    ParameterKey=VpcId,ParameterValue="$AWS_VPC_ID" \
    ParameterKey=SubnetId,ParameterValue="$AWS_SUBNET_ID" \
    ParameterKey=SshCidr,ParameterValue="$AWS_SSH_CIDR" \
    ParameterKey=PenpotSecretKey,ParameterValue=$(openssl rand -hex 32) \
    ParameterKey=PenpotVersion,ParameterValue=latest \
    ParameterKey=DeploymentMode,ParameterValue=test
```

## 9. Inspect Resources During Validation

Use the repository helper to check the current AWS resources:

```bash
./clouds/aws/scripts/resource-report.sh
```

## 10. HTTPS ALB Prerequisites

If you want to test the optional `https-alb` path, the stack needs more than the direct `HTTP` prototype flow.

Required inputs and environment assumptions:

- `AccessMode=https-alb`
- `DomainName=<customer-domain>`
- `AcmCertificateArn=<certificate-arn>` in the same AWS region
- `SubnetId=<public-subnet-a>`
- `LoadBalancerSubnetId=<public-subnet-b>`

Required AWS network shape:

- both subnets must belong to the same `VPC`
- both subnets must be public
- both subnets must be in different Availability Zones
- the customer is responsible for the DNS record that points `DomainName` to the ALB
- the customer is responsible for the certificate lifecycle and ownership; the stack only consumes `AcmCertificateArn`

## 11. Update An Existing Test Stack

If you changed the `CloudFormation` template and want to reuse the same test stack and parameters, update it with:

```bash
aws cloudformation update-stack   --region "$AWS_REGION"   --stack-name "$AWS_STACK_NAME"   --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml   --parameters     ParameterKey=AmiId,UsePreviousValue=true     ParameterKey=InstanceType,UsePreviousValue=true     ParameterKey=KeyName,UsePreviousValue=true     ParameterKey=VpcId,UsePreviousValue=true     ParameterKey=SubnetId,UsePreviousValue=true     ParameterKey=SshCidr,UsePreviousValue=true     ParameterKey=PenpotSecretKey,UsePreviousValue=true     ParameterKey=PenpotVersion,UsePreviousValue=true     ParameterKey=DeploymentMode,UsePreviousValue=true
```

Then wait for the stack update to complete:

```bash
aws cloudformation wait stack-update-complete   --region "$AWS_REGION"   --stack-name "$AWS_STACK_NAME"
```

If AWS responds with `No updates are to be performed`, the currently deployed stack already matches the template and parameters sent in the update request.

## 12. Get The Public IP Or URL

Once the stack reaches a healthy state, inspect its outputs:

```bash
aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
```

The returned outputs include the public IP, public DNS name, `PenpotUrl`, `PenpotAccessHost`, and `PenpotAccessUri`.

For browser access, prefer `PenpotAccessUri`. For host-level checks such as `curl` or SSH troubleshooting, use `PenpotAccessHost` together with the public IP or DNS output shown by the stack.

## 13. Clean Up Test Resources

When validation is complete:

```bash
./clouds/aws/scripts/cleanup.sh
```

This removes test resources associated with the current project tag.

## Technical Note

`Packer` accepts a configurable `project_tag` value so the build flow can adapt if the internal naming convention changes.

The current `CloudFormation` template still uses a fixed project tag value. This is intentional for now, because that tag is treated as part of the current internal AWS delivery model rather than as a customer-facing deployment parameter.
