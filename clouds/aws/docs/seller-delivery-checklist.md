# AWS Seller Delivery Checklist

Use this checklist after the `single-node` technical baseline is green and before treating the repository as ready for an `AWS Marketplace` seller workflow.

## 1. Technical Baseline

- `validate-https-e2e.sh` passes in a disposable test account or test environment
- `https-alb` is the reference access mode for seller-oriented validation
- `SSM Parameter Store` secrets are used instead of inline secret values
- cleanup leaves no active `EC2`, `ALB`, `AMI`, snapshot, `SSM`, or test-network resources behind
- the `CloudFormation` template validates cleanly

## 2. Release Inputs

- source `AMI` build path is prepared for `us-east-1`
- seller release variables are defined for the Marketplace workflow
- the image versioning scheme is stable and traceable
- the Marketplace source `AMI` can be identified without ambiguity

## 3. Customer-Facing Stack Shape

- required deployment inputs are documented clearly
- recommended defaults are documented for a first deployment
- `HTTPS` deployment is documented as the primary path
- secret handling guidance uses `SSM Parameter Store`
- cleanup and rollback steps are documented for operators

## 4. Marketplace Submission Assets

- product description draft exists
- support contact and escalation path are defined
- pricing approach is decided
- listing screenshots or supporting visuals are prepared if needed
- the final `CloudFormation` template intended for submission is identified

## 5. Operational Confidence

- a repeatable pre-release validation runbook exists
- a release owner is defined for Marketplace pushes
- the team knows which steps stay manual and which are automated
- failure logs from the validation flow are understandable without re-debugging the script

## Current Repository Status

At this point, the repository already covers most of the technical baseline:

- `HTTPS` end-to-end validation is automated
- `SSM` secret injection is supported in `CloudFormation`
- instance IAM for secret reads is scoped to the specific parameter ARNs
- cleanup automation covers the temporary validation resources

The main remaining seller work is no longer the base infrastructure flow. It is the release, submission, and customer-facing packaging around that flow.
