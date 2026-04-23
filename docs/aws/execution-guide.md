# AWS Execution Guide

This guide describes the current manual execution flow for the `AWS` implementation in this repository, starting from a local machine with `AWS CLI`, `Packer`, and repository access already available.

For lower-level lookup commands, see [AWS Commands Cheatsheet](commands-cheatsheet.md).

## 1. Discover Your Local AWS Profile

List the profiles available on your machine:

<details>
<summary>Show command</summary>

```bash
aws configure list-profiles
```

</details>

Choose the profile you want to use for this repository.

## 2. Log In To AWS

If your selected profile uses `AWS SSO`, log in with:

<details>
<summary>Show login command</summary>

```bash
aws sso login --profile <profile>
```

</details>

Then verify access:

<details>
<summary>Show verification command</summary>

```bash
AWS_PROFILE=<profile> aws sts get-caller-identity
```

</details>

## 3. Prepare Reusable Environment Variables

You can keep the main values in a local `.envrc` or export them in your current shell:

<details>
<summary>Show env exports</summary>

```bash
export AWS_PROFILE="<profile>"
export AWS_REGION="<region>"
export AWS_VPC_ID="<vpc-id>"
export AWS_SUBNET_ID="<subnet-id>"
export AWS_KEY_NAME="<key-pair-name>"
export AWS_STACK_NAME="<stack-name>"
export AWS_SSH_CIDR="$(curl -fsSL https://checkip.amazonaws.com)/32"
export PROJECT_TAG="<project-tag>"
export DOMAIN_NAME="<domain-name>"
export ACM_CERTIFICATE_ARN="<certificate-arn>"
export ROOT_VOLUME_SIZE="<root-volume-size>"
export ACCESS_MODE="<access-mode>"
export DATABASE_MODE="<database-mode>"
export DEPLOYMENT_MODE="<deployment-mode>"
export PENPOT_VERSION="<penpot-version>"
export BUILD_VARIANT="<build-variant>"
export AWS_AMI_ID="<ami-id>"
```

</details>

Key variables used in the current flow:

| Variable | Use | Example |
|---|---|---|
| `AWS_SSH_CIDR` | Restrict SSH access to the current public IP | `$(curl -fsSL https://checkip.amazonaws.com)/32` |
| `DOMAIN_NAME` | Public DNS name used with `https-alb` | `penpot.example.com` |
| `ACM_CERTIFICATE_ARN` | ACM certificate used by the HTTPS listener | `arn:aws:acm:...` |
| `ROOT_VOLUME_SIZE` | Root EBS volume size in GiB for Docker/runtime storage | `30` |
| `ACCESS_MODE` | Public access model | `https-alb` |
| `DATABASE_MODE` | Database topology | `local` or `external` |
| `DEPLOYMENT_MODE` | Penpot runtime behavior | `test` or `production` |
| `PENPOT_VERSION` | Target Penpot application version | `x.x.x` |
| `BUILD_VARIANT` | Optional AMI build distinction without changing the real Penpot release version | `any-custom-variant` |
| `AWS_AMI_ID` | Specific AMI to deploy through CloudFormation | `ami-...` |

Recommended lookup commands:

- profile list: [AWS Commands Cheatsheet](commands-cheatsheet.md#caller-identity)
- VPCs: [AWS Commands Cheatsheet](commands-cheatsheet.md#vpcs)
- subnets: [AWS Commands Cheatsheet](commands-cheatsheet.md#subnets)
- key pairs: [AWS Commands Cheatsheet](commands-cheatsheet.md#key-pairs)

Recommended example:

<details>
<summary>Show example exports</summary>

```bash
export AWS_STACK_NAME="penpot-cloud-image-aws-demo"
export PROJECT_TAG="penpot-cloud-image-aws"
export AWS_SSH_CIDR="203.0.113.10/32"
```

</details>

Replace `203.0.113.10/32` with the public IPv4 CIDR that should be allowed to reach the instance over SSH.

You can discover your current public IPv4 with:

<details>
<summary>Show public IP command</summary>

```bash
curl -fsSL https://checkip.amazonaws.com
```

</details>

Then export it as a `/32` CIDR, for example:

<details>
<summary>Show CIDR export</summary>

```bash
export AWS_SSH_CIDR="203.0.113.10/32"
```

</details>

This example name is only intended for the current manual testing flow. It is not meant to define the final long-term stack naming convention.

## 4. Create Or Reuse An EC2 Key Pair

If you already have a key pair in the target region, list it with:

<details>
<summary>Show key pair list command</summary>

```bash
aws ec2 describe-key-pairs \
  --region "$AWS_REGION" \
  --query 'KeyPairs[].KeyName' \
  --output table
```

</details>

If you need to create one:

<details>
<summary>Show key pair create command</summary>

```bash
aws ec2 create-key-pair \
  --region "$AWS_REGION" \
  --key-name <key-pair-name> \
  --query 'KeyMaterial' \
  --output text > <key-pair-name>.pem
chmod 400 <key-pair-name>.pem
```

</details>

Then export the chosen key pair name:

<details>
<summary>Show key name export</summary>

```bash
export AWS_KEY_NAME="<key-pair-name>"
```

</details>

## 5. Build The AMI With Packer

Before creating resources, you can run the lightweight validation helper:

<details>
<summary>Show validation command</summary>

```bash
bash clouds/aws/scripts/validate.sh
```

</details>

This checks script syntax, validates the `Packer` template, and runs `CloudFormation` template validation without launching resources.

## 6. Build The AMI With Packer

Run the build from the repository root:

<details>
<summary>Show basic Packer build</summary>

```bash
packer build \
  -var "aws_region=$AWS_REGION" \
  -var "project_tag=$PROJECT_TAG" \
  -var "vpc_id=$AWS_VPC_ID" \
  -var "subnet_id=$AWS_SUBNET_ID" \
  clouds/aws/packer/single-node.pkr.hcl
```

</details>

When the build succeeds, note the generated `AMI ID`.

If you need to distinguish a special infrastructure flavor while keeping the Penpot release version clean, add an optional `build_variant`. This keeps:

- `release_version`: the real Penpot version
- `build_variant`: the infrastructure/build distinction

Example:

<details>
<summary>Show Packer build with variant</summary>

```bash
packer build \
  -var "aws_region=$AWS_REGION" \
  -var "project_tag=$PROJECT_TAG" \
  -var "release_version=2.14.2" \
  -var "build_variant=ssm" \
  -var "vpc_id=$AWS_VPC_ID" \
  -var "subnet_id=$AWS_SUBNET_ID" \
  clouds/aws/packer/single-node.pkr.hcl
```

</details>

That produces an AMI name like:

```text
penpot-cloud-image-aws-2.14.2-ssm
```

while the version tag remains:

```text
Version=2.14.2
```

## 7. Export The New AMI ID

Keep the latest built `AMI ID` in the current shell:

<details>
<summary>Show AMI export</summary>

```bash
export AWS_AMI_ID="<ami-id>"
```

</details>

Example of the final `Packer` output:

```text
--> penpot-cloud-image-aws.amazon-ebs.al2023: AMIs were created:
eu-west-1: ami-0123456789abcdef0
```

In that case:

<details>
<summary>Show example AMI export</summary>

```bash
export AWS_AMI_ID="ami-0123456789abcdef0"
```

</details>

## 8. Launch The CloudFormation Stack

Create the stack using the AMI you just built:

<details>
<summary>Show local database create-stack command</summary>

```bash
aws cloudformation create-stack \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=AmiId,ParameterValue="$AWS_AMI_ID" \
    ParameterKey=InstanceType,ParameterValue=t3.medium \
    ParameterKey=RootVolumeSize,ParameterValue=20 \
    ParameterKey=KeyName,ParameterValue="$AWS_KEY_NAME" \
    ParameterKey=VpcId,ParameterValue="$AWS_VPC_ID" \
    ParameterKey=SubnetId,ParameterValue="$AWS_SUBNET_ID" \
    ParameterKey=SshCidr,ParameterValue="$AWS_SSH_CIDR" \
    ParameterKey=DatabaseMode,ParameterValue=local \
    ParameterKey=PenpotSecretKey,ParameterValue=$(openssl rand -hex 32) \
    ParameterKey=PenpotVersion,ParameterValue=latest \
    ParameterKey=DeploymentMode,ParameterValue=test
```

</details>

If you want Penpot to use an external PostgreSQL server instead of the local container, switch `DatabaseMode` and add the required connection parameters:

<details>
<summary>Show external database create-stack command</summary>

```bash
aws cloudformation create-stack \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=AmiId,ParameterValue="$AWS_AMI_ID" \
    ParameterKey=InstanceType,ParameterValue=t3.medium \
    ParameterKey=RootVolumeSize,ParameterValue=20 \
    ParameterKey=KeyName,ParameterValue="$AWS_KEY_NAME" \
    ParameterKey=VpcId,ParameterValue="$AWS_VPC_ID" \
    ParameterKey=SubnetId,ParameterValue="$AWS_SUBNET_ID" \
    ParameterKey=SshCidr,ParameterValue="$AWS_SSH_CIDR" \
    ParameterKey=DatabaseMode,ParameterValue=external \
    ParameterKey=ExternalDatabaseHost,ParameterValue="<db-host>" \
    ParameterKey=ExternalDatabasePort,ParameterValue=5432 \
    ParameterKey=ExternalDatabaseName,ParameterValue=penpot \
    ParameterKey=ExternalDatabaseUsername,ParameterValue="<db-user>" \
    ParameterKey=ExternalDatabasePassword,ParameterValue="<db-password>" \
    ParameterKey=PenpotSecretKey,ParameterValue=$(openssl rand -hex 32) \
    ParameterKey=PenpotVersion,ParameterValue=latest \
    ParameterKey=DeploymentMode,ParameterValue=test
```

</details>

## 9. Inspect Resources During Validation

Use the repository helper to check the current AWS resources:

<details>
<summary>Show resource report command</summary>

```bash
./clouds/aws/scripts/resource-report.sh
```

</details>

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

<details>
<summary>Show generic update-stack command</summary>

```bash
aws cloudformation update-stack \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=AmiId,UsePreviousValue=true \
    ParameterKey=InstanceType,UsePreviousValue=true \
    ParameterKey=RootVolumeSize,UsePreviousValue=true \
    ParameterKey=KeyName,UsePreviousValue=true \
    ParameterKey=VpcId,UsePreviousValue=true \
    ParameterKey=SubnetId,UsePreviousValue=true \
    ParameterKey=LoadBalancerSubnetId,UsePreviousValue=true \
    ParameterKey=SshCidr,UsePreviousValue=true \
    ParameterKey=AccessMode,UsePreviousValue=true \
    ParameterKey=PenpotPublicUri,UsePreviousValue=true \
    ParameterKey=PenpotSecretKey,UsePreviousValue=true \
    ParameterKey=PenpotVersion,UsePreviousValue=true \
    ParameterKey=DeploymentMode,UsePreviousValue=true \
    ParameterKey=DatabaseMode,UsePreviousValue=true \
    ParameterKey=DomainName,UsePreviousValue=true \
    ParameterKey=AcmCertificateArn,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseHost,UsePreviousValue=true \
    ParameterKey=ExternalDatabasePort,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseName,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseUsername,UsePreviousValue=true \
    ParameterKey=ExternalDatabasePassword,UsePreviousValue=true \
    ParameterKey=PenpotEnableSmtp,UsePreviousValue=true \
    ParameterKey=PenpotSmtpDefaultFrom,UsePreviousValue=true \
    ParameterKey=PenpotSmtpDefaultReplyTo,UsePreviousValue=true \
    ParameterKey=PenpotSmtpHost,UsePreviousValue=true \
    ParameterKey=PenpotSmtpPort,UsePreviousValue=true \
    ParameterKey=PenpotSmtpUsername,UsePreviousValue=true \
    ParameterKey=PenpotSmtpPassword,UsePreviousValue=true \
    ParameterKey=PenpotSmtpTls,UsePreviousValue=true \
    ParameterKey=PenpotSmtpSsl,UsePreviousValue=true
```

</details>

Then wait for the stack update to complete:

<details>
<summary>Show wait command</summary>

```bash
aws cloudformation wait stack-update-complete   --region "$AWS_REGION"   --stack-name "$AWS_STACK_NAME"
```

</details>

If AWS responds with `No updates are to be performed`, the currently deployed stack already matches the template and parameters sent in the update request.

## 12. In-Place Penpot Upgrade Through CloudFormation And SSM

For the current `DatabaseMode=local` path, do not update Penpot by changing `AmiId`. That replaces the EC2 instance and loses local Docker state. The supported upgrade path is to keep the same instance and update `PenpotVersion`.

Validated example:

- initial version: `2.14.2`
- updated version: `2.14.3`
- local application data preserved

Use a root volume large enough for Docker image extraction and local runtime state. For current tests, `20 GiB` is the minimum and `30 GiB` is the safer value.

<details>
<summary>Show upgrade command</summary>

```bash
aws cloudformation update-stack \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --template-body file://clouds/aws/cloudformation/penpot-single-node.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=AmiId,UsePreviousValue=true \
    ParameterKey=InstanceType,UsePreviousValue=true \
    ParameterKey=RootVolumeSize,UsePreviousValue=true \
    ParameterKey=KeyName,UsePreviousValue=true \
    ParameterKey=VpcId,UsePreviousValue=true \
    ParameterKey=SubnetId,UsePreviousValue=true \
    ParameterKey=LoadBalancerSubnetId,UsePreviousValue=true \
    ParameterKey=SshCidr,UsePreviousValue=true \
    ParameterKey=AccessMode,UsePreviousValue=true \
    ParameterKey=PenpotPublicUri,UsePreviousValue=true \
    ParameterKey=PenpotSecretKey,UsePreviousValue=true \
    ParameterKey=PenpotVersion,ParameterValue=2.14.3 \
    ParameterKey=DeploymentMode,UsePreviousValue=true \
    ParameterKey=DatabaseMode,UsePreviousValue=true \
    ParameterKey=DomainName,UsePreviousValue=true \
    ParameterKey=AcmCertificateArn,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseHost,UsePreviousValue=true \
    ParameterKey=ExternalDatabasePort,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseName,UsePreviousValue=true \
    ParameterKey=ExternalDatabaseUsername,UsePreviousValue=true \
    ParameterKey=ExternalDatabasePassword,UsePreviousValue=true \
    ParameterKey=PenpotEnableSmtp,UsePreviousValue=true \
    ParameterKey=PenpotSmtpDefaultFrom,UsePreviousValue=true \
    ParameterKey=PenpotSmtpDefaultReplyTo,UsePreviousValue=true \
    ParameterKey=PenpotSmtpHost,UsePreviousValue=true \
    ParameterKey=PenpotSmtpPort,UsePreviousValue=true \
    ParameterKey=PenpotSmtpUsername,UsePreviousValue=true \
    ParameterKey=PenpotSmtpPassword,UsePreviousValue=true \
    ParameterKey=PenpotSmtpTls,UsePreviousValue=true \
    ParameterKey=PenpotSmtpSsl,UsePreviousValue=true
```

```bash
aws cloudformation wait stack-update-complete \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME"
```

</details>

The stack uses `SSM` to run:

```bash
/opt/penpot/bin/upgrade-penpot.sh <new-penpot-version>
```

on the existing instance, so the local Docker volumes remain attached to the same EC2 host.

For direct debugging only, the helper is still available manually on the instance:

<details>
<summary>Show manual instance command</summary>

```bash
sudo /opt/penpot/bin/upgrade-penpot.sh 2.14.3
```

</details>

## 13. Get The Public IP Or URL

Once the stack reaches a healthy state, inspect its outputs:

<details>
<summary>Show outputs command</summary>

```bash
aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$AWS_STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
```

</details>

The returned outputs include the public IP, public DNS name, `PenpotUrl`, `PenpotAccessHost`, and `PenpotAccessUri`.

For browser access, prefer `PenpotAccessUri`. For host-level checks such as `curl` or SSH troubleshooting, use `PenpotAccessHost` together with the public IP or DNS output shown by the stack.

## 14. Clean Up Test Resources

When validation is complete:

<details>
<summary>Show cleanup command</summary>

```bash
./clouds/aws/scripts/cleanup.sh
```

</details>

This removes test resources associated with the current project tag.

## Technical Note

`Packer` accepts a configurable `project_tag` value so the build flow can adapt if the internal naming convention changes.

The current `CloudFormation` template still uses a fixed project tag value. This is intentional for now, because that tag is treated as part of the current internal AWS delivery model rather than as a customer-facing deployment parameter.
