# AWS Commands Cheatsheet

Reference commands used during `single-node` testing.

These commands are intended for:

- inspection
- validation
- table output when useful
- low-cost queries where possible

Use with your own values:

```bash
AWS_PROFILE=<profile>
AWS_REGION=<region>
```

## Caller Identity

```bash
AWS_PROFILE=<profile> aws sts get-caller-identity
```

## Key Pairs

```bash
AWS_PROFILE=<profile> aws ec2 describe-key-pairs \
  --region <region> \
  --query 'KeyPairs[].KeyName' \
  --output table
```

## VPCs

```bash
AWS_PROFILE=<profile> aws ec2 describe-vpcs \
  --region <region> \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

## Subnets

```bash
AWS_PROFILE=<profile> aws ec2 describe-subnets \
  --region <region> \
  --query 'Subnets[].{SubnetId:SubnetId,VpcId:VpcId,Az:AvailabilityZone,Cidr:CidrBlock,MapPublicIpOnLaunch:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

## One Subnet

```bash
AWS_PROFILE=<profile> aws ec2 describe-subnets \
  --region <region> \
  --subnet-ids <subnet-id> \
  --query 'Subnets[].{SubnetId:SubnetId,MapPublicIpOnLaunch:MapPublicIpOnLaunch,AvailableIpAddressCount:AvailableIpAddressCount,VpcId:VpcId,Az:AvailabilityZone}' \
  --output table
```

## Route Tables For One Subnet

```bash
AWS_PROFILE=<profile> aws ec2 describe-route-tables \
  --region <region> \
  --filters Name=association.subnet-id,Values=<subnet-id> \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Routes[].{Dest:DestinationCidrBlock,GatewayId:GatewayId,NatGatewayId:NatGatewayId,State:State}}' \
  --output table
```

## Internet Gateways For One VPC

```bash
AWS_PROFILE=<profile> aws ec2 describe-internet-gateways \
  --region <region> \
  --filters Name=attachment.vpc-id,Values=<vpc-id> \
  --query 'InternetGateways[].{InternetGatewayId:InternetGatewayId,Attachments:Attachments}' \
  --output table
```

## CloudFormation Stacks

```bash
AWS_PROFILE=<profile> aws cloudformation list-stacks \
  --region <region> \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE UPDATE_IN_PROGRESS UPDATE_COMPLETE DELETE_FAILED ROLLBACK_COMPLETE ROLLBACK_FAILED \
  --output table
```

## CloudFormation Resources For One Stack

```bash
AWS_PROFILE=<profile> aws cloudformation describe-stack-resources \
  --region <region> \
  --stack-name <stack-name> \
  --output table
```

## Project Resource Report

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh
```

## Project Cleanup

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh
```

## Packer Build

```bash
AWS_PROFILE=<profile> packer build \
  -var "aws_region=<region>" \
  -var "vpc_id=<vpc-id>" \
  -var "subnet_id=<subnet-id>" \
  clouds/aws/packer/single-node.pkr.hcl
```
