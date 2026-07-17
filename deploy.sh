#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="${STACK_NAME:-}"
STACK_TAG="${STACK_TAG:-}"
AWS_REGION="${AWS_REGION:-}"
S3_BUCKET="${S3_BUCKET:-}"
RELEASE_ID="${RELEASE_ID:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --stack-name NAME        CloudFormation stack name    (required)
  --stack-tag TAG          Environment tag              (required)
  --region REGION          AWS region                   (required)
  --s3-bucket BUCKET       S3 bucket for artifacts      (required)
  --release-id ID          Release identifier           (required)
  --help                   Show this help message

Environment variables STACK_NAME, STACK_TAG, AWS_REGION,
 S3_BUCKET, and RELEASE_ID are also accepted.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack-name)    STACK_NAME="$2";    shift 2 ;;
        --stack-tag)     STACK_TAG="$2";     shift 2 ;;
        --region)        AWS_REGION="$2";    shift 2 ;;
        --s3-bucket)     S3_BUCKET="$2";     shift 2 ;;
        --release-id)    RELEASE_ID="$2";    shift 2 ;;
        --help)          usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "${STACK_NAME}" ]]; then
    echo "Error: --stack-name or STACK_NAME is required" >&2
    exit 1
fi

if [[ -z "${STACK_TAG}" ]]; then
    echo "Error: --stack-tag or STACK_TAG is required" >&2
    exit 1
fi

if [[ -z "${AWS_REGION}" ]]; then
    echo "Error: --region or AWS_REGION is required" >&2
    exit 1
fi

if [[ -z "${S3_BUCKET}" ]]; then
    echo "Error: --s3-bucket or S3_BUCKET is required" >&2
    exit 1
fi

if [[ -z "${RELEASE_ID}" ]]; then
    echo "Error: --release-id or RELEASE_ID is required" >&2
    exit 1
fi

FULL_STACK_NAME="${STACK_NAME}-${STACK_TAG}"
S3_PREFIX="${STACK_NAME}"
TEMPLATE_FILE="${SCRIPT_DIR}/${STACK_NAME}-${RELEASE_ID}.yaml"

echo "> Downloading template from s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/"
aws s3 cp \
    "s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/${STACK_NAME}-${RELEASE_ID}.yaml" \
    "${TEMPLATE_FILE}" \
    --region "${AWS_REGION}"

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "Error: failed to download template file" >&2
    exit 1
fi

echo "Deploying stack ${FULL_STACK_NAME} in ${AWS_REGION}"

echo "> Validating template"
aws cloudformation validate-template \
    --template-body "file://${TEMPLATE_FILE}" \
    --region "${AWS_REGION}" \
    --output table

echo "> Deploying stack"
aws cloudformation deploy \
    --template-file "${TEMPLATE_FILE}" \
    --stack-name "${FULL_STACK_NAME}" \
    --region "${AWS_REGION}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags \
        Environment="${STACK_TAG}" \
        intent="data-migration" \
        ReleaseId="${RELEASE_ID}" \
    --parameter-overrides \
        StackTag="${STACK_TAG}" \
    --no-fail-on-empty-changeset

echo "> Stack outputs"
aws cloudformation describe-stacks \
    --stack-name "${FULL_STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query "Stacks[0].Outputs" \
    --output table

echo "Deployment complete"
