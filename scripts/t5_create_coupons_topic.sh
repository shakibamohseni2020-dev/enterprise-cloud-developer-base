#!/bin/bash

TOPIC_NAME="coupons"
REGION="us-east-1"

function fail() {
  echo $2
  exit $1
}

echo "Creating SNS topic ${TOPIC_NAME}"
TOPIC_ARN=$(awslocal sns create-topic \
    --region ${REGION} \
    --name "${TOPIC_NAME}" \
    --attributes DisplayName="Ideal Trip Coupons" \
    --query TopicArn --output text)
[ $? == 0 ] && [ -n "${TOPIC_ARN}" ] || fail 1 "Failed to create topic"
echo "Topic ARN: ${TOPIC_ARN}"

echo "${TOPIC_NAME} topic created successfully"
