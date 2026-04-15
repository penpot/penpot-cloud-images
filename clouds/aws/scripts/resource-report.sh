#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "--list" ]]; then
  cat <<'EOF'
Usage:
  AWS_PROFILE=<profile> ./clouds/aws/scripts/resource-report.sh [profile] [region]

Description:
  Lists AWS resources related to the Penpot single-node project.

Reports:
  - CloudFormation stacks
  - EC2 instances
  - AMIs
  - Snapshots
  - Security groups
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

echo "AWS resource report"
echo "profile: ${PROFILE}"
echo "region: ${REGION}"
echo "project tag: ${PROJECT_TAG}"
echo

echo "CloudFormation stacks"
aws_cmd cloudformation list-stacks \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE ROLLBACK_IN_PROGRESS ROLLBACK_COMPLETE ROLLBACK_FAILED DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE \
  --query "StackSummaries[?contains(StackName, 'penpot')].[StackName,StackStatus]" \
  --output table || true
echo

echo "EC2 instances"
aws_cmd ec2 describe-instances \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
  --query "Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key=='Name']|[0].Value,PublicDnsName]" \
  --output table || true
echo

echo "AMIs"
aws_cmd ec2 describe-images \
  --owners self \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "Images[].[ImageId,Name,CreationDate,State]" \
  --output table || true
echo

echo "Snapshots"
aws_cmd ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "Snapshots[].[SnapshotId,StartTime,State,VolumeSize]" \
  --output table || true
echo

echo "Security groups"
aws_cmd ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
  --query "SecurityGroups[].[GroupId,GroupName,Description]" \
  --output table || true
