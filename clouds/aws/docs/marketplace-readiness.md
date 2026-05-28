# AWS Marketplace Readiness

This repository already builds and deploys a working `single-node` Penpot image on `AWS`, but the seller path adds extra constraints beyond the current manual test flow.

## Scope

Use this document when preparing an `AMI-based` AWS Marketplace product backed by the assets in this repository.

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

## Canonical Source AMI Release Flow

Use the dedicated GitHub Actions workflow:

- `.github/workflows/aws-marketplace-ami-release.yml`

This is the canonical seller release flow for producing the source `AMI` intended for `AWS Marketplace`.

Scope of this flow:

- build the Marketplace source `AMI`
- produce the source `AMI` ID to carry into Marketplace registration or submission

This flow does not cover:

- listing content
- pricing
- support policy
- final submission in the Marketplace Management Portal

Release procedure:

1. confirm the Marketplace build network exists in `us-east-1`
2. confirm the required repository variables and secret are set
3. trigger `AWS Marketplace Source AMI Release` with optional inputs:
   - `penpot_release_version`
   - `build_variant`
4. wait for the workflow to complete successfully
5. record the resulting source `AMI` ID from the job summary

Treat that `AMI` as the release handoff for the next seller step.

## Publication Package

The current publication package for this repository is:

- product shape: `AMI with CloudFormation`
- source `AMI`: the artifact produced by `.github/workflows/aws-marketplace-ami-release.yml` in `us-east-1`
- publication template: `clouds/aws/cloudformation/penpot-single-node.yaml`

## Official Customer Deployment Path

Treat this as the default customer-facing deployment path for the Marketplace package:

- `AccessMode=https-alb`
- `PenpotPublicUri=""`
- `DeploymentMode=production`
- `DatabaseMode=local`
- `ValkeyMode=local`
- `PenpotSecretKeySsmParameterName` backed by `SSM Parameter Store SecureString`

Customer prerequisites for this path:

- one `VPC`
- two public subnets in different Availability Zones
- one `EC2` key pair
- one public `DomainName`
- one `ACM` certificate in the same region
- one DNS record pointing the customer hostname to the `ALB`

This path is the closest thing to the current first-class customer deployment flow. Other options in the template remain useful, but they should be treated as advanced variants unless explicitly elevated later.

## Publication Template Parameters

For `v1`, treat the following as the intended customer surface. Everything else should be considered advanced unless later promoted explicitly.

### Required for the official deployment path

- `AmiId`
- `KeyName`
- `VpcId`
- `SubnetId`
- `LoadBalancerSubnetId`
- `SshCidr`
- `AccessMode=https-alb`
- `PenpotVersion`
- `DomainName`
- `AcmCertificateArn`
- `PenpotSecretKeySsmParameterName`

### Recommended defaults for the official deployment path

- `InstanceType=t3.medium`
- `RootVolumeSize=20` or larger if you want more Docker/runtime headroom
- `PenpotPublicUri=""`
- `DeploymentMode=production`
- `DatabaseMode=local`
- `ValkeyMode=local`
- `PenpotEnableSmtp=false`

### Optional advanced parameters

- `ExternalDatabaseHost`
- `ExternalDatabasePort`
- `ExternalDatabaseName`
- `ExternalDatabaseUsername`
- `ExternalDatabasePassword`
- `ExternalDatabasePasswordSsmParameterName`
- `ExternalValkeyUri`
- `PenpotEnableSmtp`
- `PenpotSmtpDefaultFrom`
- `PenpotSmtpDefaultReplyTo`
- `PenpotSmtpHost`
- `PenpotSmtpPort`
- `PenpotSmtpUsername`
- `PenpotSmtpPassword`
- `PenpotSmtpPasswordSsmParameterName`
- `PenpotSmtpTls`
- `PenpotSmtpSsl`

## Submission Handoff

For a real Marketplace submission, the minimum handoff from the repository side is:

- the source `AMI` ID built in `us-east-1`
- the final `CloudFormation` template path
- the official customer deployment path above
- the required and recommended parameter set above
- the seller gap status below, so it is clear what is still commercial or operational rather than infrastructure-related

## Seller Gap Status

Status legend:

- `Done`: covered in the repository and already validated
- `Partial`: present, but still needs tightening or explicit closure
- `Missing`: still outside the current repository closure

### 1. Technical Baseline

Status: `Done`

- `validate-https-e2e.sh` passes in a disposable test account or test environment
- `https-alb` is the reference access mode for seller-oriented validation
- `SSM Parameter Store` secrets are used instead of inline secret values
- cleanup leaves no active `EC2`, `ALB`, `AMI`, snapshot, `SSM`, or test-network resources behind
- the `CloudFormation` template validates cleanly

### 2. Release Inputs

Status: `Done`

- source `AMI` build path is prepared for `us-east-1`
- seller release variables are defined for the Marketplace workflow
- the image versioning scheme is stable and traceable
- the Marketplace source `AMI` can be identified without ambiguity
- the canonical seller release flow is documented in this file

### 3. Customer-Facing Stack Shape

Status: `Partial`

- required deployment inputs are documented clearly
- recommended defaults are documented for a first deployment
- `HTTPS` deployment is documented as the primary path
- secret handling guidance uses `SSM Parameter Store`
- cleanup and rollback steps are documented for operators

What is still missing here:

- one clearly identified customer-facing deployment path, rather than a repo-internal operator perspective
- a final pass on which inputs are required, optional, and recommended for a first customer deployment

### 4. Marketplace Submission Assets

Status: `Missing`

- product description draft exists
- support contact and escalation path are defined
- pricing approach is decided
- listing screenshots or supporting visuals are prepared if needed
- the final `CloudFormation` template intended for submission is identified

### 5. Operational Confidence

Status: `Partial`

- a repeatable pre-release validation runbook exists
- a release owner is defined for Marketplace pushes
- the team knows which steps stay manual and which are automated
- failure logs from the validation flow are understandable without re-debugging the script

What is still missing here:

- named ownership for Marketplace release execution
- one short runbook that distinguishes validation, release, and submission responsibilities

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

## Definition Of Done

Treat the repository as `seller-ready technical` when all of this is true:

- the technical baseline stays `Done`
- release inputs stay `Done`
- customer-facing stack shape is promoted from `Partial` to `Done`
- operational confidence is promoted from `Partial` to `Done`

Treat the repository as ready for full `AWS Marketplace publication` only when the Marketplace submission assets are also closed.
