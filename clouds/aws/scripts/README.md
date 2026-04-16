# AWS Scripts

Operational helper scripts for the current `AWS` delivery flow.

Both scripts use `PROJECT_TAG=penpot-cloud-image-aws` by default, but allow a temporary override through the `PROJECT_TAG` environment variable when needed.

## Scripts

- `resource-report.sh`
  Lists the AWS resources currently associated with this project, including stacks, instances, AMIs, snapshots, and security groups.

- `cleanup.sh`
  Cleans project resources in `AWS` and prints the state before and after cleanup.

## Typical Usage

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh
AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh
```
