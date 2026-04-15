# Cleanup Workflow

## Goal

Make AWS test runs observable before and after cleanup so we can verify that no project resources are left behind.

## Project Resource Convention

Tracked resources use:

- tag `Project=penpot-cloud-image-aws`
- tag `Repository=penpot-cloud-images`

This is applied to:

- Packer-created AMIs
- Packer-created snapshots
- Packer builder resources where tagging is supported
- CloudFormation-created EC2 instance
- CloudFormation-created security group

## Scripts

### Resource report

Use:

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh
```

This lists:

- matching CloudFormation stacks
- tagged EC2 instances
- tagged AMIs
- tagged snapshots
- tagged security groups

### Cleanup

Use:

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh
```

This script:

1. prints a `before` report
2. deletes matching CloudFormation stacks
3. terminates tagged EC2 instances
4. deregisters tagged AMIs
5. deletes tagged snapshots
6. attempts to delete tagged security groups
7. prints an `after` report

## Safety Model

The cleanup is intentionally limited to resources tagged as:

- `Project=penpot-cloud-image-aws`

and CloudFormation stack names containing:

- `penpot`

## Recommended Usage

Before a test:

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh
```

After a test:

```bash
AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh
```

Then verify the `after` report is empty for project resources.
