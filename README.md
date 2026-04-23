# penpot-cloud-images

Build and deployment assets for Penpot cloud images, initially focused on AWS.

## Scope

This repository contains the working area for a Penpot `single-node` cloud distribution, structured to expand by provider while keeping a shared runtime contract.

Current direction:

- `Distribution model`: `AMI + CloudFormation`
- `Runtime model`: Penpot on a single virtual machine using Docker Compose
- `Current implementation target`: a first testable `AWS` `V1` using EC2 public IP over `HTTP`

The goal is to reuse the official Penpot self-hosting path instead of creating a custom runtime.

## Repository Structure

- `clouds/aws/`: AWS-specific Packer, CloudFormation, and operational scripts
- `clouds/azure/`: reserved for future Azure-specific image and deployment definitions
- `clouds/gcp/`: reserved for future GCP-specific image and deployment definitions
- `shared/`: runtime assets shared across clouds
- `docs/`: architecture notes, operational checklists, references, and runbooks

## AWS Scope

The current `AWS` implementation covers:

- Packer build for the base EC2 image
- CloudFormation template for the customer launch flow
- AWS operational scripts for resource reporting and cleanup

## Key Paths

- AWS Packer template: `clouds/aws/packer/single-node.pkr.hcl`
- AWS CloudFormation template: `clouds/aws/cloudformation/penpot-single-node.yaml`
- AWS validation helper: `clouds/aws/scripts/validate.sh`
- AWS scripts guide: `clouds/aws/scripts/README.md`
- AWS scripts: `clouds/aws/scripts/resource-report.sh`, `clouds/aws/scripts/cleanup.sh`
- Shared scripts: `shared/scripts/`
- Shared templates: `shared/templates/`
- Shared systemd units: `shared/systemd/`

## Documentation

- [AWS Execution Guide](docs/aws/execution-guide.md)
- [Cleanup Checklist](docs/aws/cleanup-checklist.md)
- [AWS Commands Cheatsheet](docs/aws/commands-cheatsheet.md)

## Current Build Flow

1. Build an EC2 AMI with Docker, Docker Compose plugin, Penpot compose files, helper scripts, and a systemd unit.
2. Launch the AMI through CloudFormation.
3. Pass runtime configuration through CloudFormation parameters and EC2 user data.
4. Configure Penpot on first boot, start the stack with `docker compose`, and expose it through host-level `nginx` on port `80`.

## Current Upgrade Flow

For the current `DatabaseMode=local` path, application upgrades should be done in place on the existing EC2 instance by updating `PenpotVersion` through `CloudFormation`, not by replacing the instance with a new `AmiId`.

This flow was validated from `2.14.2` to `2.14.3` while preserving local application data.

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
    ParameterKey=PenpotVersion,ParameterValue=<new-version> \
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

For AWS accounts without a `default VPC`, the Packer build must be run with explicit `vpc_id` and `subnet_id`.

On the current Amazon Linux 2023 base image, `docker-compose-plugin` may not be available as a package. The current AMI build installs Docker Compose v2 explicitly as a Docker CLI plugin.

For test deployments without external DNS, the CloudFormation template can derive `PENPOT_PUBLIC_URI` from the EC2 public IP on first boot.

SMTP is exposed as CloudFormation parameters so each customer deployment can provide its own mail relay without rebuilding the AMI.

The CloudFormation template supports:

- `DeploymentMode=production`: normal customer behavior, intended for SMTP-backed email flows
- `DeploymentMode=test`: adds `disable-email-verification` for internal validation without email

If `PenpotEnableSmtp` is left as `false`, Penpot starts without `enable-smtp` and the SMTP parameters are effectively ignored.

## Current Assumptions

- `single-node`
- local PostgreSQL volume
- local assets volume
- no HA
- no EKS
- no autoscaling
- no DNS requirement for the first test version
- public access through EC2 public IP over `HTTP`
