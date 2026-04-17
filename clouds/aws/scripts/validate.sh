#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash clouds/aws/scripts/validate.sh

Description:
  Runs lightweight validation for the current AWS delivery flow without creating resources.

Checks:
  - shell syntax for repository scripts
  - packer fmt -check
  - packer init
  - packer validate
  - aws cloudformation validate-template

Environment:
  AWS_REGION   Optional. Defaults to eu-west-1.
  PROJECT_TAG  Optional. Defaults to penpot-cloud-image-aws.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT_TAG="${PROJECT_TAG:-penpot-cloud-image-aws}"
PACKER_TEMPLATE="clouds/aws/packer/single-node.pkr.hcl"
CFN_TEMPLATE="clouds/aws/cloudformation/penpot-single-node.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd aws
require_cmd bash
require_cmd packer

echo "Checking shell script syntax"
bash -n clouds/aws/scripts/*.sh
bash -n shared/scripts/*.sh
echo

echo "Checking Packer formatting"
packer fmt -check "$PACKER_TEMPLATE"
echo

echo "Initializing Packer plugins"
packer init "$PACKER_TEMPLATE" >/dev/null
echo

echo "Validating Packer template"
packer validate \
  -var "aws_region=$AWS_REGION" \
  -var "project_tag=$PROJECT_TAG" \
  "$PACKER_TEMPLATE"
echo

echo "Validating CloudFormation template"
aws cloudformation validate-template \
  --region "$AWS_REGION" \
  --template-body "file://$CFN_TEMPLATE" >/dev/null
echo

echo "AWS validation completed successfully"
