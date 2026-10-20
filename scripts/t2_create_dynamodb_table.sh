#!/bin/bash

TABLE_NAME="coupons"
REGION="us-east-1"

# Capacity math (average item size = 1 KB):
#   Reads:  1 RCU = 2 eventually consistent reads/sec for items up to 4 KB
#           50 eventually consistent reads/sec / 2 = 25 RCU
#   Writes: 1 WCU = 1 write/sec for items up to 1 KB
#           10 writes/sec * 1 = 10 WCU
READ_CAPACITY=25
WRITE_CAPACITY=10

function fail() {
  echo $2
  exit $1
}

echo "Creating DynamoDB table ${TABLE_NAME} (RCU=${READ_CAPACITY}, WCU=${WRITE_CAPACITY})"
awslocal dynamodb create-table \
    --region ${REGION} \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=coupon_id,AttributeType=S \
    --key-schema AttributeName=coupon_id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=${READ_CAPACITY},WriteCapacityUnits=${WRITE_CAPACITY}
[ $? == 0 ] || fail 1 "Failed to create DynamoDB table"

echo "Waiting for table to be active"
awslocal dynamodb wait table-exists --region ${REGION} --table-name "${TABLE_NAME}"
[ $? == 0 ] || fail 2 "Table did not become active"

echo "Loading sample coupons into ${TABLE_NAME}"
awslocal dynamodb batch-write-item \
    --region ${REGION} \
    --request-items file://scripts/t2_coupons_sample_items.json
[ $? == 0 ] || fail 3 "Failed to load sample coupons"

echo "Items in table:"
awslocal dynamodb scan --region ${REGION} --table-name "${TABLE_NAME}" --select COUNT

echo "${TABLE_NAME} table created successfully"
