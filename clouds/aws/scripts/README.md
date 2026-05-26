# AWS Scripts

Operational helper scripts for the current `AWS` delivery flow.

`resource-report.sh` and `cleanup.sh` use `PROJECT_TAG=penpot-cloud-image-aws` by default, but allow a temporary override through the `PROJECT_TAG` environment variable when needed.

## Scripts

- `resource-report.sh`
  Lists the AWS resources currently associated with this project, including stacks, instances, AMIs, snapshots, security groups, and matching `/penpot/` SSM parameters. If `HTTPS_TEST_VPC_ID` is set, it also shows the temporary HTTPS test network.

- `cleanup.sh`
  Cleans project resources in `AWS`, removes matching `/penpot/` SSM parameters, and prints the state before and after cleanup. If `HTTPS_TEST_*` variables are set, it also attempts to remove the temporary HTTPS test network.

- `validate.sh`
  Runs lightweight static validation for the AWS delivery assets without creating resources.

## Typical Usage

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh
AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh
bash ./clouds/aws/scripts/validate.sh
bash ./clouds/aws/scripts/validate.sh --help
```
