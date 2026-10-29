#!/bin/bash

BUCKET_NAME="coupons"
REGION="us-east-1"

function fail() {
  echo $2
  exit $1
}

# Denies s3:DeleteObject / s3:DeleteObjectVersion on any imported file
# unless the request was made with multi-factor authentication.
echo "Adding delete-requires-MFA policy to ${BUCKET_NAME}"
awslocal s3api put-bucket-policy \
    --region ${REGION} \
    --bucket "${BUCKET_NAME}" \
    --policy file://scripts/t4_coupons_bucket_policy.json
[ $? == 0 ] || fail 1 "Failed to add bucket policy"

echo "Current bucket policy:"
awslocal s3api get-bucket-policy --region ${REGION} --bucket "${BUCKET_NAME}" --query Policy --output text
[ $? == 0 ] || fail 2 "Failed to read bucket policy"

echo "Bucket policy added successfully"
