#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="${STACK_NAME:-}"
STACK_TAG="${STACK_TAG:-}"
AWS_REGION="${AWS_REGION:-}"
S3_BUCKET="${S3_BUCKET:-}"
RELEASE_ID="${RELEASE_ID:-}"

TEMPLATE_FILE="${SCRIPT_DIR}/template.yaml"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --stack-name NAME        Stack name prefix            (required)
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

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "Error: template file not found at ${TEMPLATE_FILE}" >&2
    exit 1
fi

FULL_STACK_NAME="${STACK_NAME}-${STACK_TAG}"
S3_PREFIX="${STACK_NAME}"

echo "Packaging stack ${FULL_STACK_NAME} in ${AWS_REGION}"

echo "> Building Python dependencies"
BUILD_DIR="${SCRIPT_DIR}/.build"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cp -r "${SCRIPT_DIR}/src/"* "${BUILD_DIR}/"
if [[ -f "${SCRIPT_DIR}/requirements.txt" ]]; then
    pip install -r "${SCRIPT_DIR}/requirements.txt" -t "${BUILD_DIR}/" --quiet
fi

OUTPUT_TEMPLATE_FILE="${BUILD_DIR}/${STACK_NAME}-${RELEASE_ID}.yaml"

echo "> Uploading state machine definition to s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/statemachine/"
aws s3 cp "${SCRIPT_DIR}/statemachine/data_migration.asl.json" \
    "s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/statemachine/data_migration.asl.json" \
    --region "${AWS_REGION}"
SM_S3_URI="s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/statemachine/data_migration.asl.json"

echo "> Packaging template (uploading artifacts to s3://${S3_BUCKET}/${S3_PREFIX})"
aws cloudformation package \
    --template-file "${TEMPLATE_FILE}" \
    --s3-bucket "${S3_BUCKET}" \
    --s3-prefix "${S3_PREFIX}" \
    --region "${AWS_REGION}" \
    --output-template-file "${OUTPUT_TEMPLATE_FILE}"

echo "> Patching DefinitionUri with S3 path"
sed -i "s|DefinitionUri: statemachine/data_migration.asl.json|DefinitionUri: ${SM_S3_URI}|g" "${OUTPUT_TEMPLATE_FILE}"

echo "> Packaged template written to ${OUTPUT_TEMPLATE_FILE}"

echo "> Uploading packaged template to s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/"
aws s3 cp "${OUTPUT_TEMPLATE_FILE}" \
    "s3://${S3_BUCKET}/${S3_PREFIX}/${RELEASE_ID}/" \
    --region "${AWS_REGION}"

echo "Packaging complete"
