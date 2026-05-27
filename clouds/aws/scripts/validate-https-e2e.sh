#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  AWS_PROFILE=<profile> bash clouds/aws/scripts/validate-https-e2e.sh [--create-network]

Description:
  Runs an end-to-end HTTPS validation for the Penpot single-node AWS flow.

What it does:
  - optionally creates a temporary HTTPS test network
  - builds a temporary AMI with Packer
  - creates a temporary SSM SecureString secret
  - deploys a temporary CloudFormation stack in https-alb mode
  - waits for CREATE_COMPLETE
  - checks HTTPS reachability through the ALB using the requested DOMAIN_NAME with SNI
  - cleans up all temporary resources on exit

Required environment:
  AWS_PROFILE
  AWS_REGION
  PROJECT_TAG
  PENPOT_VERSION
  AWS_KEY_NAME
  DOMAIN_NAME
  ACM_CERTIFICATE_ARN
  AWS_SSH_CIDR

Network environment:
  Reuse existing network:
    AWS_VPC_ID
    AWS_SUBNET_ID
    LOAD_BALANCER_SUBNET_ID

  Or let the script create one temporarily:
    --create-network

Optional environment:
  ROOT_VOLUME_SIZE     Defaults to 30
  INSTANCE_TYPE        Defaults to t3.medium
  DEPLOYMENT_MODE      Defaults to test
  BUILD_VARIANT        Optional custom AMI suffix
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

CREATE_NETWORK=false
if [[ "${1:-}" == "--create-network" ]]; then
  CREATE_NETWORK=true
elif [[ -n "${1:-}" ]]; then
  echo "unknown argument: ${1}" >&2
  usage >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT_TAG="${PROJECT_TAG:-penpot-cloud-image-aws}"
ROOT_VOLUME_SIZE="${ROOT_VOLUME_SIZE:-30}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-test}"
PACKER_TEMPLATE="clouds/aws/packer/single-node.pkr.hcl"
CFN_TEMPLATE="clouds/aws/cloudformation/penpot-single-node.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "missing required environment variable: ${var_name}" >&2
    exit 1
  fi
}

aws_cmd() {
  aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" "$@"
}

log() {
  printf '%s\n' "$*"
}

wait_for_target_group_healthy() {
  local target_group_arn="$1"
  local attempts="${2:-30}"
  local sleep_seconds="${3:-10}"
  local attempt=1
  local target_state
  local target_state_output
  local target_state_status

  while (( attempt <= attempts )); do
    set +e
    target_state_output="$(
      aws_cmd elbv2 describe-target-health \
        --target-group-arn "${target_group_arn}" \
        --query 'TargetHealthDescriptions[0].TargetHealth.State' \
        --output text 2>&1
    )"
    target_state_status=$?
    set -e

    if (( target_state_status != 0 )); then
      log "Target health query failed (${attempt}/${attempts}): ${target_state_output}"
      sleep "${sleep_seconds}"
      ((attempt++))
      continue
    fi

    target_state="${target_state_output}"

    if [[ "${target_state}" == "healthy" ]]; then
      return 0
    fi

    log "Target group state: ${target_state} (${attempt}/${attempts})"
    sleep "${sleep_seconds}"
    ((attempt++))
  done

  log "Target group did not become healthy after ${attempts} attempts"
  return 1
}

wait_for_https_smoke_test() {
  local domain_name="$1"
  local alb_dns_name="$2"
  local attempts="${3:-12}"
  local sleep_seconds="${4:-10}"
  local attempt=1

  while (( attempt <= attempts )); do
    if curl \
      --fail \
      --silent \
      --show-error \
      --head \
      --connect-to "${domain_name}:443:${alb_dns_name}:443" \
      "https://${domain_name}/" >/dev/null; then
      return 0
    fi

    log "HTTPS smoke test not ready yet (${attempt}/${attempts})"
    sleep "${sleep_seconds}"
    ((attempt++))
  done

  log "HTTPS smoke test did not succeed after ${attempts} attempts"
  return 1
}

wait_for_dns_resolution() {
  local dns_name="$1"
  local attempts="${2:-18}"
  local sleep_seconds="${3:-10}"
  local attempt=1

  while (( attempt <= attempts )); do
    if [[ -n "$(dig +short "${dns_name}")" ]]; then
      return 0
    fi

    log "ALB DNS not resolving yet (${attempt}/${attempts})"
    sleep "${sleep_seconds}"
    ((attempt++))
  done

  log "ALB DNS did not resolve after ${attempts} attempts"
  return 1
}

CLEANUP_STACK=true
CLEANUP_AMI=true
CLEANUP_SSM=true
CLEANUP_NETWORK=false
VALIDATION_SUCCEEDED=false
AWS_AMI_ID=""
AWS_STACK_NAME=""
PENPOT_SECRET_SSM_PARAM=""
STACK_SNAPSHOT_IDS=()
HTTPS_TEST_VPC_ID=""
HTTPS_TEST_SUBNET_ID_A=""
HTTPS_TEST_SUBNET_ID_B=""
HTTPS_TEST_IGW_ID=""
HTTPS_TEST_ROUTE_TABLE_ID=""
INSTANCE_ID=""
ALB_DNS_NAME=""
TARGET_GROUP_ARN=""
VALIDATION_ID="$(date +%Y%m%d%H%M%S)"
BUILD_VARIANT_BASE="${BUILD_VARIANT:-https-e2e}"
BUILD_VARIANT="${BUILD_VARIANT_BASE}-${VALIDATION_ID}"

collect_failure_diagnostics() {
  local ssm_payload
  local command_id

  if [[ -n "${TARGET_GROUP_ARN}" ]]; then
    log "Failure diagnostic: target group health"
    aws_cmd elbv2 describe-target-health --target-group-arn "${TARGET_GROUP_ARN}" || true
  fi

  if [[ -n "${ALB_DNS_NAME}" ]]; then
    log "Failure diagnostic: ALB DNS resolution"
    dig +short "${ALB_DNS_NAME}" || true
  fi

  if [[ -n "${INSTANCE_ID}" ]]; then
    log "Failure diagnostic: collecting instance state through SSM"
    ssm_payload="$(mktemp)"
    cat >"${ssm_payload}" <<'EOF'
{
  "commands": [
    "sudo systemctl status penpot-compose --no-pager",
    "sudo journalctl -u penpot-compose -n 80 --no-pager",
    "sudo journalctl -u nginx -n 80 --no-pager",
    "curl -I http://localhost/",
    "docker ps --format \"{{.Names}} {{.Status}}\""
  ]
}
EOF
    command_id="$(
      aws_cmd ssm send-command \
        --instance-ids "${INSTANCE_ID}" \
        --document-name AWS-RunShellScript \
        --parameters "file://${ssm_payload}" \
        --query 'Command.CommandId' \
        --output text
    )"
    aws_cmd ssm wait command-executed --command-id "${command_id}" --instance-id "${INSTANCE_ID}" || true
    aws_cmd ssm get-command-invocation --command-id "${command_id}" --instance-id "${INSTANCE_ID}" || true
    rm -f "${ssm_payload}"
  fi
}

cleanup() {
  set +e

  if [[ "${VALIDATION_SUCCEEDED}" != "true" ]]; then
    collect_failure_diagnostics
  fi

  if [[ "${CLEANUP_STACK}" == "true" && -n "${AWS_STACK_NAME}" ]]; then
    log
    log "Cleaning up CloudFormation stack: ${AWS_STACK_NAME}"
    aws_cmd cloudformation delete-stack --stack-name "${AWS_STACK_NAME}" >/dev/null 2>&1
    aws_cmd cloudformation wait stack-delete-complete --stack-name "${AWS_STACK_NAME}" >/dev/null 2>&1
  fi

  if [[ "${CLEANUP_SSM}" == "true" && -n "${PENPOT_SECRET_SSM_PARAM}" ]]; then
    log "Deleting SSM parameter: ${PENPOT_SECRET_SSM_PARAM}"
    aws_cmd ssm delete-parameter --name "${PENPOT_SECRET_SSM_PARAM}" >/dev/null 2>&1
  fi

  if [[ "${CLEANUP_AMI}" == "true" && -n "${AWS_AMI_ID}" ]]; then
    log "Deregistering AMI: ${AWS_AMI_ID}"
    aws_cmd ec2 deregister-image --image-id "${AWS_AMI_ID}" >/dev/null 2>&1
    for snapshot_id in "${STACK_SNAPSHOT_IDS[@]:-}"; do
      if [[ -n "${snapshot_id}" && "${snapshot_id}" != "None" ]]; then
        log "Deleting snapshot: ${snapshot_id}"
        aws_cmd ec2 delete-snapshot --snapshot-id "${snapshot_id}" >/dev/null 2>&1
      fi
    done
  fi

  if [[ "${CLEANUP_NETWORK}" == "true" && -n "${HTTPS_TEST_VPC_ID}" ]]; then
    log "Deleting temporary HTTPS test network"

    if [[ -n "${HTTPS_TEST_ROUTE_TABLE_ID}" ]] && aws_cmd ec2 describe-route-tables --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}" >/dev/null 2>&1; then
      for assoc_id in $(
        aws_cmd ec2 describe-route-tables \
          --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}" \
          --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
          --output text
      ); do
        [[ -n "${assoc_id}" && "${assoc_id}" != "None" ]] && aws_cmd ec2 disassociate-route-table --association-id "${assoc_id}" >/dev/null 2>&1
      done

      if [[ "$(aws_cmd ec2 describe-route-tables --route-table-ids "${HTTPS_TEST_ROUTE_TABLE_ID}" --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' --output text)" != "None" ]]; then
        aws_cmd ec2 delete-route --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" --destination-cidr-block 0.0.0.0/0 >/dev/null 2>&1
      fi
    fi

    for subnet_id in "${HTTPS_TEST_SUBNET_ID_A}" "${HTTPS_TEST_SUBNET_ID_B}"; do
      [[ -n "${subnet_id}" ]] && aws_cmd ec2 delete-subnet --subnet-id "${subnet_id}" >/dev/null 2>&1
    done

    if [[ -n "${HTTPS_TEST_IGW_ID}" ]]; then
      aws_cmd ec2 detach-internet-gateway --internet-gateway-id "${HTTPS_TEST_IGW_ID}" --vpc-id "${HTTPS_TEST_VPC_ID}" >/dev/null 2>&1
      aws_cmd ec2 delete-internet-gateway --internet-gateway-id "${HTTPS_TEST_IGW_ID}" >/dev/null 2>&1
    fi

    [[ -n "${HTTPS_TEST_ROUTE_TABLE_ID}" ]] && aws_cmd ec2 delete-route-table --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" >/dev/null 2>&1
    aws_cmd ec2 delete-vpc --vpc-id "${HTTPS_TEST_VPC_ID}" >/dev/null 2>&1
  fi
}

trap cleanup EXIT

require_cmd aws
require_cmd bash
require_cmd curl
require_cmd dig
require_cmd packer
require_cmd sed
require_cmd openssl

require_var AWS_PROFILE
require_var PENPOT_VERSION
require_var AWS_KEY_NAME
require_var DOMAIN_NAME
require_var ACM_CERTIFICATE_ARN
require_var AWS_SSH_CIDR

if [[ "${CREATE_NETWORK}" == "false" ]]; then
  require_var AWS_VPC_ID
  require_var AWS_SUBNET_ID
  require_var LOAD_BALANCER_SUBNET_ID
fi

log "Checking ACM certificate"
aws_cmd acm describe-certificate \
  --certificate-arn "${ACM_CERTIFICATE_ARN}" \
  --query 'Certificate.[CertificateArn,Status]' \
  --output table >/dev/null

create_https_test_network() {
  local rand_octet
  rand_octet=$((RANDOM % 200 + 20))

  HTTPS_TEST_VPC_ID="$(
    aws_cmd ec2 create-vpc \
      --cidr-block "10.${rand_octet}.0.0/16" \
      --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=penpot-https-test-${VALIDATION_ID}}]" \
      --query 'Vpc.VpcId' \
      --output text
  )"

  aws_cmd ec2 modify-vpc-attribute --vpc-id "${HTTPS_TEST_VPC_ID}" --enable-dns-support '{"Value":true}' >/dev/null
  aws_cmd ec2 modify-vpc-attribute --vpc-id "${HTTPS_TEST_VPC_ID}" --enable-dns-hostnames '{"Value":true}' >/dev/null

  HTTPS_TEST_SUBNET_ID_A="$(
    aws_cmd ec2 create-subnet \
      --vpc-id "${HTTPS_TEST_VPC_ID}" \
      --cidr-block "10.${rand_octet}.1.0/24" \
      --availability-zone "${AWS_REGION}a" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=penpot-https-test-a-${VALIDATION_ID}}]" \
      --query 'Subnet.SubnetId' \
      --output text
  )"

  HTTPS_TEST_SUBNET_ID_B="$(
    aws_cmd ec2 create-subnet \
      --vpc-id "${HTTPS_TEST_VPC_ID}" \
      --cidr-block "10.${rand_octet}.2.0/24" \
      --availability-zone "${AWS_REGION}b" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=penpot-https-test-b-${VALIDATION_ID}}]" \
      --query 'Subnet.SubnetId' \
      --output text
  )"

  aws_cmd ec2 modify-subnet-attribute --subnet-id "${HTTPS_TEST_SUBNET_ID_A}" --map-public-ip-on-launch >/dev/null
  aws_cmd ec2 modify-subnet-attribute --subnet-id "${HTTPS_TEST_SUBNET_ID_B}" --map-public-ip-on-launch >/dev/null

  HTTPS_TEST_IGW_ID="$(
    aws_cmd ec2 create-internet-gateway \
      --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=penpot-https-test-${VALIDATION_ID}}]" \
      --query 'InternetGateway.InternetGatewayId' \
      --output text
  )"

  aws_cmd ec2 attach-internet-gateway --internet-gateway-id "${HTTPS_TEST_IGW_ID}" --vpc-id "${HTTPS_TEST_VPC_ID}" >/dev/null

  HTTPS_TEST_ROUTE_TABLE_ID="$(
    aws_cmd ec2 create-route-table \
      --vpc-id "${HTTPS_TEST_VPC_ID}" \
      --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=penpot-https-test-${VALIDATION_ID}}]" \
      --query 'RouteTable.RouteTableId' \
      --output text
  )"

  aws_cmd ec2 create-route \
    --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "${HTTPS_TEST_IGW_ID}" >/dev/null

  aws_cmd ec2 associate-route-table --subnet-id "${HTTPS_TEST_SUBNET_ID_A}" --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" >/dev/null
  aws_cmd ec2 associate-route-table --subnet-id "${HTTPS_TEST_SUBNET_ID_B}" --route-table-id "${HTTPS_TEST_ROUTE_TABLE_ID}" >/dev/null

  AWS_VPC_ID="${HTTPS_TEST_VPC_ID}"
  AWS_SUBNET_ID="${HTTPS_TEST_SUBNET_ID_A}"
  LOAD_BALANCER_SUBNET_ID="${HTTPS_TEST_SUBNET_ID_B}"
  CLEANUP_NETWORK=true
}

if [[ "${CREATE_NETWORK}" == "true" ]]; then
  log "Creating temporary HTTPS test network"
  create_https_test_network
fi

log "Initializing Packer plugins"
packer init "${PACKER_TEMPLATE}" >/dev/null

log "Building temporary AMI with Packer"
PACKER_LOG="/tmp/penpot-https-e2e-${VALIDATION_ID}.log"
packer build \
  -machine-readable \
  -var "aws_region=${AWS_REGION}" \
  -var "project_tag=${PROJECT_TAG}" \
  -var "release_version=${PENPOT_VERSION}" \
  -var "build_variant=${BUILD_VARIANT}" \
  -var "vpc_id=${AWS_VPC_ID}" \
  -var "subnet_id=${AWS_SUBNET_ID}" \
  "${PACKER_TEMPLATE}" | tee "${PACKER_LOG}" >/dev/null

AWS_AMI_ID="$(sed -n 's/.*artifact,0,id,[^:]*:\(ami-[A-Za-z0-9]*\).*/\1/p' "${PACKER_LOG}" | tail -n1)"
if [[ -z "${AWS_AMI_ID}" ]]; then
  echo "failed to extract AMI ID from Packer output" >&2
  exit 1
fi

mapfile -t STACK_SNAPSHOT_IDS < <(
  aws_cmd ec2 describe-images \
    --image-ids "${AWS_AMI_ID}" \
    --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \
    --output text | tr '\t' '\n'
)

AWS_STACK_NAME="penpot-cloud-image-aws-https-e2e-${VALIDATION_ID}"
PENPOT_SECRET_SSM_PARAM="/penpot/${AWS_STACK_NAME}/secret-key"

log "Creating temporary SSM secret"
aws_cmd ssm put-parameter \
  --name "${PENPOT_SECRET_SSM_PARAM}" \
  --type SecureString \
  --value "$(openssl rand -hex 32)" >/dev/null

log "Creating temporary HTTPS stack"
aws_cmd cloudformation create-stack \
  --stack-name "${AWS_STACK_NAME}" \
  --template-body "file://${CFN_TEMPLATE}" \
  --capabilities CAPABILITY_IAM \
  --parameters \
    "ParameterKey=AmiId,ParameterValue=${AWS_AMI_ID}" \
    "ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE}" \
    "ParameterKey=RootVolumeSize,ParameterValue=${ROOT_VOLUME_SIZE}" \
    "ParameterKey=KeyName,ParameterValue=${AWS_KEY_NAME}" \
    "ParameterKey=VpcId,ParameterValue=${AWS_VPC_ID}" \
    "ParameterKey=SubnetId,ParameterValue=${AWS_SUBNET_ID}" \
    "ParameterKey=LoadBalancerSubnetId,ParameterValue=${LOAD_BALANCER_SUBNET_ID}" \
    "ParameterKey=SshCidr,ParameterValue=${AWS_SSH_CIDR}" \
    "ParameterKey=AccessMode,ParameterValue=https-alb" \
    "ParameterKey=DomainName,ParameterValue=${DOMAIN_NAME}" \
    "ParameterKey=AcmCertificateArn,ParameterValue=${ACM_CERTIFICATE_ARN}" \
    "ParameterKey=DatabaseMode,ParameterValue=local" \
    "ParameterKey=ValkeyMode,ParameterValue=local" \
    "ParameterKey=PenpotSecretKeySsmParameterName,ParameterValue=${PENPOT_SECRET_SSM_PARAM}" \
    "ParameterKey=PenpotVersion,ParameterValue=${PENPOT_VERSION}" \
    "ParameterKey=DeploymentMode,ParameterValue=${DEPLOYMENT_MODE}" >/dev/null

log "Waiting for stack CREATE_COMPLETE"
aws_cmd cloudformation wait stack-create-complete --stack-name "${AWS_STACK_NAME}"

ALB_DNS_NAME="$(
  aws_cmd cloudformation describe-stacks \
    --stack-name "${AWS_STACK_NAME}" \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDnsName`].OutputValue' \
    --output text
)"
TARGET_GROUP_ARN="$(
  aws_cmd cloudformation describe-stack-resources \
    --stack-name "${AWS_STACK_NAME}" \
    --logical-resource-id PenpotTargetGroup \
    --query 'StackResources[0].PhysicalResourceId' \
    --output text
)"
INSTANCE_ID="$(
  aws_cmd cloudformation describe-stack-resources \
    --stack-name "${AWS_STACK_NAME}" \
    --query 'StackResources[?ResourceType==`AWS::EC2::Instance`].PhysicalResourceId' \
    --output text
)"

if [[ -z "${ALB_DNS_NAME}" ]]; then
  echo "failed to resolve LoadBalancerDnsName from stack outputs" >&2
  exit 1
fi

if [[ -z "${TARGET_GROUP_ARN}" || "${TARGET_GROUP_ARN}" == "None" ]]; then
  echo "failed to resolve target group ARN from stack resources" >&2
  exit 1
fi

log "Waiting for ALB target to become healthy"
wait_for_target_group_healthy "${TARGET_GROUP_ARN}" 60 10

log "Waiting for ALB DNS to resolve"
wait_for_dns_resolution "${ALB_DNS_NAME}" 18 10

log "Running HTTPS smoke test against ALB"
wait_for_https_smoke_test "${DOMAIN_NAME}" "${ALB_DNS_NAME}" 18 10

VALIDATION_SUCCEEDED=true

log
log "HTTPS end-to-end validation passed"
log "stack: ${AWS_STACK_NAME}"
log "ami: ${AWS_AMI_ID}"
log "alb: ${ALB_DNS_NAME}"
log "domain: ${DOMAIN_NAME}"
