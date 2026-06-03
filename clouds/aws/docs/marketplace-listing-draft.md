# AWS Marketplace Listing Draft

Use this draft as the working document for review with marketing, product, and the technical team before completing the `AWS Marketplace` listing.

## Product Shape

- listing type: `AMI with CloudFormation`
- candidate source `AMI` region: `us-east-1`
- candidate source `AMI` ID: `ami-07521192d68b2c9ff`
- deployment path: `https-alb`

## Public Listing Draft

The following sections contain draft customer-facing copy. Do not copy internal notes, open decisions, or blockers into the public listing.

## Working Product Name

`Penpot Single-Node for AWS`

Alternative options for review:

- `Penpot for AWS`
- `Penpot Single-Node Deployment for AWS`
- `Penpot Self-Hosted on AWS`

## Working Short Description

`Deploy Penpot on AWS using a prebuilt AMI and CloudFormation, with HTTPS through an Application Load Balancer and a guided single-node setup.`

## Working Long Description

`Penpot Single-Node for AWS provides a straightforward way to deploy a self-hosted Penpot environment in your AWS account using an Amazon Machine Image (AMI) and AWS CloudFormation.

The current package is designed for teams that want a simple first deployment path with HTTPS exposure through an Application Load Balancer, a customer-managed domain, and secret handling through AWS Systems Manager Parameter Store.

The default deployment path is intended for a single-node setup with local PostgreSQL and local Valkey on the host. Advanced operators can use documented configuration options for external database, external cache, and SMTP-backed email flows if needed.

This product is best suited for evaluation, internal collaboration, controlled team usage, and customers who want a clear AWS-native deployment path for Penpot in their own account.`

## Value Proposition

- deploy Penpot in your own `AWS` account
- launch through `AWS CloudFormation`
- `HTTPS` through `ALB` and `ACM`
- secrets handled through `AWS Systems Manager Parameter Store`
- simple default path for a first deployment
- documented options for operators who need external services

## Intended Customer

- teams that want to self-host Penpot on `AWS`
- customers who prefer infrastructure in their own account
- operators who want a guided single-node deployment before moving to more customized topologies

## Customer Deployment Summary

Default deployment assumptions for the first listing version:

- `AccessMode=https-alb`
- `DeploymentMode=production`
- `DatabaseMode=local`
- `ValkeyMode=local`
- `PenpotSecretKeySsmParameterName` provided through `SSM Parameter Store`

Customer prerequisites:

- one `VPC`
- two public subnets in different Availability Zones
- one `EC2` key pair
- one public domain
- one `ACM` certificate in the target region
- one DNS record pointing the hostname to the `ALB`

## Internal Review Notes

The following sections are for internal review and submission preparation. They should be resolved before the final `AWS Marketplace` submission.

## Pricing

Status: pending `Growth` team decision

Pricing ownership:

- the `AWS Marketplace` pricing model should be confirmed by the `Growth` team
- the public Penpot pricing page can be used as reference context
- the public pricing page should not be treated as the final `AWS Marketplace` pricing model unless `Growth` confirms it

Open pricing decisions:

- free listing or paid listing
- hourly, annual, contract, private offer, or other model
- whether support is included in the listing price
- whether the first version should optimize for adoption, validation, or revenue

Internal note:

- pricing must remain open until confirmed by `Growth`
- do not treat the listing package as publication-complete until pricing is approved

## Support

Status: provisional

Provisional support contact:

- support email: `support@penpot.app`
- general self-hosting documentation: <https://help.penpot.app/technical-guide/getting-started/>
- `AWS Marketplace` deployment guide: `TBD`

Minimum fields to confirm before submission:

- support email
- documentation URL
- issue escalation path
- expected response window

Internal notes:

- confirm whether `AWS Marketplace` or self-hosted customers require a dedicated support alias or support routing
- the current documentation URL is valid as general self-hosting documentation, but an `AWS`-specific `AMI + CloudFormation` deployment guide may still be required before submission
- if support will initially be lightweight, state that clearly and avoid implying a stronger SLA than the team can actually sustain

## Categories And Keywords

Working category candidates:

- Design
- Collaboration
- Developer Tools

Working keyword candidates:

- `penpot`
- `design`
- `ui`
- `ux`
- `prototype`
- `collaboration`
- `self-hosted`
- `aws`
- `cloudformation`

## Submission Blockers

- final `AWS Marketplace` pricing model pending `Growth` decision
- final support route and expected response window pending confirmation
- `AWS`-specific `AMI + CloudFormation` deployment guide pending
- final public product name pending approval
- candidate source `AMI` approval pending for submission use
- final positioning pending: evaluation-ready versus production-ready for small teams

## Technical Validation Status

- `Packer` formatting check: passed
- `Packer` initialization: passed
- `Packer` template validation: passed
- `CloudFormation` template validation: passed
- validation command: `bash clouds/aws/scripts/validate.sh`

Technical notes:

- the listing default path matches `clouds/aws/docs/marketplace-readiness.md`
- the template exposes the expected parameters for `AccessMode=https-alb`, `DeploymentMode=production`, `DatabaseMode=local`, `ValkeyMode=local`, and `PenpotSecretKeySsmParameterName`
- the template currently defaults `AccessMode` to `http-direct`; the Marketplace path still explicitly requires `AccessMode=https-alb`

## Open Decisions

- final public product name
- final pricing model
- final support statement
- final category choice
- final keyword list
- whether the listing should describe the product primarily as evaluation-ready or production-ready for small teams

Recommended current positioning:

- use `best suited for evaluation, internal collaboration, and controlled team usage`
- avoid stronger production-readiness language until product, support, and technical review explicitly approve it

## Review Outcome

Use this section after the internal review.

- approved name:
- approved short description:
- approved long description:
- approved pricing model:
- approved support contact:
- approved categories:
- approved keywords:
- approved for submission: `yes/no`
