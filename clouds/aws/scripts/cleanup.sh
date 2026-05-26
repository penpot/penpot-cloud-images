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
  - Deletes matching SSM parameters under /penpot/
  - Optionally deletes the HTTPS test network when HTTPS_TEST_* variables are set
  - Prints an after report
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

aws_safe_delete() {
  if ! aws_cmd "$@"; then
    echo "warning: command failed, continuing: aws $*" >&2
  fi
}

resource_exists() {
  aws_cmd "$@" >/dev/null 2>&1
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
echo "Deleting matching SSM parameters"
mapfile -t ssm_parameters < <(aws_cmd ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=${SSM_PARAMETER_PREFIX}" \
  --query "Parameters[?contains(Name, \`${PROJECT_TAG}\`)].Name" \
  --output text | tr '\t' '\n')

for parameter_name in "${ssm_parameters[@]:-}"; do
  if [[ -n "${parameter_name}" ]]; then
    echo "Deleting SSM parameter: ${parameter_name}"
    aws_safe_delete ssm delete-parameter --name "${parameter_name}"
  fi
done

if [[ -n "${HTTPS_TEST_VPC_ID:-}" ]]; then
  echo
  echo "Deleting HTTPS test network resources"

  if [[ -n "${HTTPS_TEST_ROUTE_TABLE_ID:-}" ]] && resource_exists ec2 describe-route-tables --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}"; then
    for assoc_id in $(
      aws_cmd ec2 describe-route-tables \
        --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}" \
        --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
        --output text
    ); do
      if [[ -n "${assoc_id}" && "${assoc_id}" != "None" ]]; then
        aws_safe_delete ec2 disassociate-route-table --association-id "${assoc_id}"
      fi
    done

    default_route_gateway="$(
      aws_cmd ec2 describe-route-tables \
        --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}" \
        --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' \
        --output text
    )"
    if [[ -n "${default_route_gateway}" && "${default_route_gateway}" != "None" ]]; then
      aws_safe_delete ec2 delete-route \
        --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" \
        --destination-cidr-block 0.0.0.0/0
    fi
  fi

  for subnet_id in "${HTTPS_TEST_SUBNET_ID_A:-}" "${HTTPS_TEST_SUBNET_ID_B:-}"; do
    if [[ -n "${subnet_id}" ]] && resource_exists ec2 describe-subnets --subnet-ids "${subnet_id}"; then
      echo "Deleting subnet: ${subnet_id}"
      aws_safe_delete ec2 delete-subnet --subnet-id "${subnet_id}"
    fi
  done

  if [[ -n "${HTTPS_TEST_IGW_ID:-}" ]] && resource_exists ec2 describe-internet-gateways --internet-gateway-ids "${HTTPS_TEST_IGW_ID}"; then
    aws_safe_delete ec2 detach-internet-gateway \
      --internet-gateway-id "${HTTPS_TEST_IGW_ID}" \
      --vpc-id "${HTTPS_TEST_VPC_ID}"
    aws_safe_delete ec2 delete-internet-gateway --internet-gateway-id "${HTTPS_TEST_IGW_ID}"
  fi

  if [[ -n "${HTTPS_TEST_ROUTE_TABLE_ID:-}" ]] && resource_exists ec2 describe-route-tables --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}"; then
    aws_safe_delete ec2 delete-route-table --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}"
  fi

  if resource_exists ec2 describe-vpcs --vpc-ids "${HTTPS_TEST_VPC_ID}"; then
    aws_safe_delete ec2 delete-vpc --vpc-id "${HTTPS_TEST_VPC_ID}"
  fi
fi

echo
echo "After cleanup"
"$(dirname "$0")/resource-report.sh" "${PROFILE}" "${REGION}"
