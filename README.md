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
- AWS scripts guide: `clouds/aws/scripts/README.md`
- AWS scripts: `clouds/aws/scripts/resource-report.sh`, `clouds/aws/scripts/cleanup.sh`
- Shared scripts: `shared/scripts/`
- Shared templates: `shared/templates/`
- Shared systemd units: `shared/systemd/`

## Documentation

- [AWS Execution Guide](docs/runbooks/aws-execution-guide.md)
- [Single-Node Scope](docs/architecture/single-node-scope.md)
- [Cleanup Checklist](docs/checklists/cleanup-checklist.md)
- [AWS Commands Cheatsheet](docs/runbooks/aws-commands-cheatsheet.md)

## Current Build Flow

1. Build an EC2 AMI with Docker, Docker Compose plugin, Penpot compose files, helper scripts, and a systemd unit.
2. Launch the AMI through CloudFormation.
3. Pass runtime configuration through CloudFormation parameters and EC2 user data.
4. Configure Penpot on first boot, start the stack with `docker compose`, and expose it through host-level `nginx` on port `80`.

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
