#!/bin/bash

TOPIC_NAME="coupons"
REGION="us-east-1"
TOPIC_ARN="arn:aws:sns:${REGION}:000000000000:${TOPIC_NAME}"
# Where notifications are delivered. Override these when running the script,
# e.g. NOTIFICATION_EMAIL=me@example.com bash scripts/t5_add_policy_to_coupons_topic.sh
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-customers@idealtrip.com}"
NOTIFICATION_HTTP_ENDPOINT="${NOTIFICATION_HTTP_ENDPOINT:-http://notifications.idealtrip.com/coupons}"

function fail() {
  echo $2
  exit $1
}

# The policy lets coupons_lambda_role publish, and denies any subscription
# whose protocol is not email or http (no sms, sqs, lambda, https, etc).
echo "Adding policy to ${TOPIC_NAME} topic"
POLICY=$(tr -d '\n' < scripts/t5_coupons_topic_policy.json)
awslocal sns set-topic-attributes \
    --region ${REGION} \
    --topic-arn "${TOPIC_ARN}" \
    --attribute-name Policy \
    --attribute-value "${POLICY}"
[ $? == 0 ] || fail 1 "Failed to add topic policy"

echo "Current topic policy:"
awslocal sns get-topic-attributes \
    --region ${REGION} \
    --topic-arn "${TOPIC_ARN}" \
    --query 'Attributes.Policy' --output text
[ $? == 0 ] || fail 2 "Failed to read topic policy"

echo "Adding HTTP subscription (${NOTIFICATION_HTTP_ENDPOINT})"
awslocal sns subscribe \
    --region ${REGION} \
    --topic-arn "${TOPIC_ARN}" \
    --protocol http \
    --notification-endpoint "${NOTIFICATION_HTTP_ENDPOINT}"
[ $? == 0 ] || fail 3 "Failed to add HTTP subscription"

echo "Adding email subscription (${NOTIFICATION_EMAIL})"
awslocal sns subscribe \
    --region ${REGION} \
    --topic-arn "${TOPIC_ARN}" \
    --protocol email \
    --notification-endpoint "${NOTIFICATION_EMAIL}"
[ $? == 0 ] || fail 4 "Failed to add email subscription"

echo "Subscriptions on ${TOPIC_NAME}:"
awslocal sns list-subscriptions-by-topic \
    --region ${REGION} \
    --topic-arn "${TOPIC_ARN}" \
    --query 'Subscriptions[].{Protocol:Protocol,Endpoint:Endpoint}' --output table

echo "Topic policy added successfully"
