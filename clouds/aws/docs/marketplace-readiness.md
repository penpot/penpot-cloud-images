# AWS Marketplace Readiness

This repository already builds and deploys a working `single-node` Penpot image on `AWS`, but the seller path adds extra constraints beyond the current manual test flow.

## Scope

Use this document when preparing an `AMI-based` AWS Marketplace product backed by the assets in this repository.

For an execution-oriented follow-up checklist, see [Seller Delivery Checklist](seller-delivery-checklist.md).

The current fit is:

- `AMI with CloudFormation`

That matches the existing image build plus [cloudformation/penpot-single-node.yaml](../cloudformation/penpot-single-node.yaml).

## Current Repository Position

What already exists:

- `Packer` AMI build for the Penpot host
- `CloudFormation` deployment template for the current `single-node` flow
- release version normalization helper
- validation helper
- GitHub Actions workflow for standard AMI releases

What is new for seller preparation:

- dedicated GitHub Actions workflow for Marketplace source AMIs: `.github/workflows/aws-marketplace-ami-release.yml`
- optional `SSM Parameter Store` secret resolution in the CloudFormation template for:
  - `PenpotSecretKey`
  - `ExternalDatabasePassword`
  - `PenpotSmtpPassword`
- automated `HTTPS` end-to-end validation script: `clouds/aws/scripts/validate-https-e2e.sh`

## Marketplace Source AMI Constraint

For `AWS Marketplace`, the source `AMI` must be built in `us-east-1`.

This is different from the current manual test examples in this repository, which still default to `eu-west-1`.

Keep the two flows separate:

- manual validation or customer-like testing: any chosen test region
- Marketplace source image publication: `us-east-1`

## Required GitHub Variables For Marketplace Builds

Set these repository or environment variables before running the Marketplace workflow:

- `AWS_MARKETPLACE_SOURCE_REGION`
- `AWS_MARKETPLACE_VPC_ID`
- `AWS_MARKETPLACE_SUBNET_ID`
- `PROJECT_TAG` (optional, defaults to `penpot-cloud-image-aws`)

Recommended value:

```text
AWS_MARKETPLACE_SOURCE_REGION=us-east-1
```

The Marketplace workflow fails fast if the effective source region is not `us-east-1`.

## Manual Seller Checklist For The Next Phase

After the source AMI build is working, the next seller tasks are outside the current infrastructure flow:

- register or configure the seller account in `AWS Marketplace Management Portal`
- create the product as `AMI with CloudFormation`
- prepare listing text, support details, and pricing
- submit the source AMI and template for Marketplace review
- decide whether publication stays manual or moves to `Catalog API`

## Seller Technical Baseline

Before treating the current `single-node` flow as seller-ready enough for Marketplace-oriented iteration, keep these technical checks green:

- `https-alb` deployment path works end-to-end
- secrets can be supplied through `SSM Parameter Store` instead of inline `CloudFormation` values
- instance IAM is limited to the specific secret parameter ARNs passed through the stack
- cleanup leaves no active validation resources behind
- the `HTTPS` validation flow is reproducible from a single command

The repository now has an executable baseline for that last point:

```bash
AWS_PROFILE=<profile> bash ./clouds/aws/scripts/validate-https-e2e.sh --create-network
```

What this validates:

- temporary HTTPS network creation
- temporary `AMI` build
- temporary `SSM` secret creation
- temporary `CloudFormation` deployment in `https-alb` mode
- target health recovery behind the `ALB`
- external `HTTPS` reachability using the intended hostname and `SNI`
- full cleanup of temporary stack, secret, `AMI`, snapshot, and network

This is not the Marketplace publication workflow itself. It is the current technical confidence gate for the seller path.

## Recommended Secret Handling

For seller-oriented deployments, prefer `SSM Parameter Store` `SecureString` parameters over passing sensitive values directly as `CloudFormation` parameter values.

The template now supports these optional parameters:

- `PenpotSecretKeySsmParameterName`
- `ExternalDatabasePasswordSsmParameterName`
- `PenpotSmtpPasswordSsmParameterName`

Compatibility behavior:

- if the `...SsmParameterName` value is provided, the instance resolves the secret at boot with `aws ssm get-parameter --with-decryption`
- if the `...SsmParameterName` value is empty, the template keeps using the existing inline secret parameter
- the referenced parameter must exist in the same `AWS` account and region as the stack because instance access is scoped to the specific parameter ARN

This keeps the current flow working while giving you a cleaner path for Marketplace-oriented deployments.

## Why This Split Matters

The existing release workflow is still useful for ordinary AWS validation and internal image iteration.

The Marketplace workflow is intentionally separate so that:

- the current regional test flow is not broken
- seller-specific inputs stay explicit
- the repository can evolve toward publication without forcing all builds through `us-east-1`
