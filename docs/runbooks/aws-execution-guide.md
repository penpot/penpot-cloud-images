# AWS Execution Guide

This guide describes the current manual execution flow for the `AWS` implementation in this repository, starting from a local machine with `AWS CLI`, `Packer`, and repository access already available.

For lower-level lookup commands, see [AWS Commands Cheatsheet](aws-commands-cheatsheet.md).

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

- profile list: [AWS Commands Cheatsheet](aws-commands-cheatsheet.md#caller-identity)
- VPCs: [AWS Commands Cheatsheet](aws-commands-cheatsheet.md#vpcs)
- subnets: [AWS Commands Cheatsheet](aws-commands-cheatsheet.md#subnets)
- key pairs: [AWS Commands Cheatsheet](aws-commands-cheatsheet.md#key-pairs)

Recommended example:

```bash
export AWS_STACK_NAME="penpot-cloud-image-aws-demo"
export PROJECT_TAG="penpot-cloud-image-aws"
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

## 6. Export The New AMI ID

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

## 7. Launch The CloudFormation Stack

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
    ParameterKey=SshCidr,ParameterValue=0.0.0.0/0 \
    ParameterKey=PenpotSecretKey,ParameterValue=$(openssl rand -hex 32) \
    ParameterKey=PenpotVersion,ParameterValue=latest \
    ParameterKey=DeploymentMode,ParameterValue=test
```

## 8. Inspect Resources During Validation

Use the repository helper to check the current AWS resources:

```bash
./clouds/aws/scripts/resource-report.sh
```

## 9. Get The Public IP Or URL

Once the stack reaches a healthy state, inspect its outputs:

```bash
aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
```

The returned outputs include the public IP and the derived access URL.

## 10. Clean Up Test Resources

When validation is complete:

```bash
./clouds/aws/scripts/cleanup.sh
```

This removes test resources associated with the current project tag.

## Technical Note

`Packer` accepts a configurable `project_tag` value so the build flow can adapt if the internal naming convention changes.

The current `CloudFormation` template still uses a fixed project tag value. This is intentional for now, because that tag is treated as part of the current internal AWS delivery model rather than as a customer-facing deployment parameter.
