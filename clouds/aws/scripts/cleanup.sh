#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "--list" ]]; then
  cat <<'EOF'
Usage:
  AWS_PROFILE=<profile> ./clouds/aws/scripts/cleanup.sh [profile] [region]

Description:
  Cleans AWS resources related to the Penpot single-node project.

Actions:
  - Prints a before report
  - Deletes matching CloudFormation stacks
  - Terminates tagged EC2 instances
  - Deregisters tagged AMIs
  - Deletes tagged snapshots
  - Attempts to delete tagged security groups
  - Prints an after report
EOF
  exit 0
fi

PROFILE="${AWS_PROFILE:-${1:-}}"
REGION="${AWS_REGION:-${2:-eu-west-1}}"
PROJECT_TAG="penpot-cloud-image-aws"

if [[ -z "${PROFILE}" ]]; then
  echo "usage: AWS_PROFILE=<profile> $0 [profile] [region]" >&2
  exit 1
fi

aws_cmd() {
  aws --profile "${PROFILE}" --region "${REGION}" "$@"
}

echo "Before cleanup"
"$(dirname "$0")/resource-report.sh" "${PROFILE}" "${REGION}"
echo

echo "Deleting CloudFormation stacks containing 'penpot'"
mapfile -t stacks < <(aws_cmd cloudformation list-stacks \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE ROLLBACK_IN_PROGRESS ROLLBACK_COMPLETE ROLLBACK_FAILED DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE \
  --query "StackSummaries[?contains(StackName, 'penpot')].StackName" \
  --output text | tr '\t' '\n')

for stack in "${stacks[@]:-}"; do
  if [[ -n "${stack}" ]]; then
    echo "Deleting stack: ${stack}"
    aws_cmd cloudformation delete-stack --stack-name "${stack}"
    aws_cmd cloudformation wait stack-delete-complete --stack-name "${stack}" || true
  fi
done

echo
echo "Terminating tagged EC2 instances"
mapfile -t instances < <(aws_cmd ec2 describe-instances \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text | tr '\t' '\n')

if [[ ${#instances[@]} -gt 0 && -n "${instances[0]:-}" ]]; then
  aws_cmd ec2 terminate-instances --instance-ids "${instances[@]}" >/dev/null
  aws_cmd ec2 wait instance-terminated --instance-ids "${instances[@]}" || true
fi

echo
echo "Deregistering tagged AMIs"
mapfile -t amis < <(aws_cmd ec2 describe-images \
  --owners self \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "Images[].ImageId" \
  --output text | tr '\t' '\n')

for ami in "${amis[@]:-}"; do
  if [[ -n "${ami}" ]]; then
    echo "Deregistering AMI: ${ami}"
    aws_cmd ec2 deregister-image --image-id "${ami}"
  fi
done

echo
echo "Deleting tagged snapshots"
mapfile -t snapshots < <(aws_cmd ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "Snapshots[].SnapshotId" \
  --output text | tr '\t' '\n')

for snapshot in "${snapshots[@]:-}"; do
  if [[ -n "${snapshot}" ]]; then
    echo "Deleting snapshot: ${snapshot}"
    aws_cmd ec2 delete-snapshot --snapshot-id "${snapshot}"
  fi
done

echo
echo "Deleting tagged security groups when possible"
mapfile -t sgs < <(aws_cmd ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "SecurityGroups[].GroupId" \
  --output text | tr '\t' '\n')

for sg in "${sgs[@]:-}"; do
  if [[ -n "${sg}" ]]; then
    echo "Deleting security group: ${sg}"
    aws_cmd ec2 delete-security-group --group-id "${sg}" || true
  fi
done

echo
echo "After cleanup"
"$(dirname "$0")/resource-report.sh" "${PROFILE}" "${REGION}"
