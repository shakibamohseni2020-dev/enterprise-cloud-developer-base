#!/bin/bash

BUCKET_NAME="coupons"
REGION="us-east-1"

function fail() {
  echo $2
  exit $1
}

echo "Creating private S3 bucket ${BUCKET_NAME}"
awslocal s3api create-bucket \
    --region ${REGION} \
    --bucket "${BUCKET_NAME}" \
    --acl private
[ $? == 0 ] || fail 1 "Failed to create bucket"

echo "Blocking all public access to ${BUCKET_NAME}"
awslocal s3api put-public-access-block \
    --region ${REGION} \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
[ $? == 0 ] || fail 2 "Failed to block public access"

# Versioning keeps older copies of imported files, so an overwrite or
# delete can be recovered. It is also required for MFA delete.
echo "Enabling versioning on ${BUCKET_NAME}"
awslocal s3api put-bucket-versioning \
    --region ${REGION} \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
[ $? == 0 ] || fail 3 "Failed to enable versioning"

echo "Bucket ACL:"
awslocal s3api get-bucket-acl --region ${REGION} --bucket "${BUCKET_NAME}"

echo "${BUCKET_NAME} bucket created successfully"
