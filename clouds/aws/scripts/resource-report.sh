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
  - SSM parameters under /penpot/ for this project
  - Optional HTTPS test network resources when HTTPS_TEST_VPC_ID is set
EOF
  exit 0
fi

PROFILE="${AWS_PROFILE:-${1:-}}"
REGION="${AWS_REGION:-${2:-eu-west-1}}"
PROJECT_TAG="${PROJECT_TAG:-penpot-cloud-image-aws}"
SSM_PARAMETER_PREFIX="${SSM_PARAMETER_PREFIX:-/penpot/}"

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
echo

echo "SSM parameters"
aws_cmd ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=${SSM_PARAMETER_PREFIX}" \
  --query "Parameters[?contains(Name, \`${PROJECT_TAG}\`)].[Name,Type]" \
  --output table || true

if [[ -n "${HTTPS_TEST_VPC_ID:-}" ]]; then
  https_test_subnets=()
  if [[ -n "${HTTPS_TEST_SUBNET_ID_A:-}" ]]; then
    https_test_subnets+=("${HTTPS_TEST_SUBNET_ID_A}")
  fi
  if [[ -n "${HTTPS_TEST_SUBNET_ID_B:-}" ]]; then
    https_test_subnets+=("${HTTPS_TEST_SUBNET_ID_B}")
  fi

  echo
  echo "HTTPS test VPC"
  if aws_cmd ec2 describe-vpcs --vpc-ids "${HTTPS_TEST_VPC_ID}" >/dev/null 2>&1; then
    aws_cmd ec2 describe-vpcs \
      --vpc-ids "${HTTPS_TEST_VPC_ID}" \
      --query "Vpcs[].[VpcId,State,CidrBlock]" \
      --output table || true
  fi

  echo
  echo "HTTPS test subnets"
  if [[ ${#https_test_subnets[@]} -gt 0 ]]; then
    existing_https_test_subnets=()
    for subnet_id in "${https_test_subnets[@]}"; do
      if aws_cmd ec2 describe-subnets --subnet-ids "${subnet_id}" >/dev/null 2>&1; then
        existing_https_test_subnets+=("${subnet_id}")
      fi
    done

    if [[ ${#existing_https_test_subnets[@]} -gt 0 ]]; then
      aws_cmd ec2 describe-subnets \
        --subnet-ids "${existing_https_test_subnets[@]}" \
        --query "Subnets[].[SubnetId,State,AvailabilityZone,VpcId]" \
        --output table || true
    fi
  fi
fi
