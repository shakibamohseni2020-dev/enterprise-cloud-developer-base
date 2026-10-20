#!/bin/bash

TABLE_NAME="coupons"
INDEX_NAME="provider_id-campaign_id-index"
REGION="us-east-1"
READ_CAPACITY=25
WRITE_CAPACITY=10

function fail() {
  echo $2
  exit $1
}

# Global secondary index so coupons can be queried by provider_id
# (partition key) and campaign_id (sort key) without scanning the table.
echo "Adding ${INDEX_NAME} to ${TABLE_NAME}"
awslocal dynamodb update-table \
    --region ${REGION} \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions \
        AttributeName=provider_id,AttributeType=S \
        AttributeName=campaign_id,AttributeType=S \
    --global-secondary-index-updates \
        "[{\"Create\":{\"IndexName\":\"${INDEX_NAME}\",\"KeySchema\":[{\"AttributeName\":\"provider_id\",\"KeyType\":\"HASH\"},{\"AttributeName\":\"campaign_id\",\"KeyType\":\"RANGE\"}],\"Projection\":{\"ProjectionType\":\"ALL\"},\"ProvisionedThroughput\":{\"ReadCapacityUnits\":${READ_CAPACITY},\"WriteCapacityUnits\":${WRITE_CAPACITY}}}}]"
[ $? == 0 ] || fail 1 "Failed to add index"

echo "Waiting for index to become active"
for i in $(seq 1 30); do
  STATUS=$(awslocal dynamodb describe-table --region ${REGION} --table-name "${TABLE_NAME}" \
    --query "Table.GlobalSecondaryIndexes[?IndexName=='${INDEX_NAME}'].IndexStatus" --output text)
  [ "${STATUS}" == "ACTIVE" ] && break
  sleep 2
done
echo "Index status: ${STATUS}"

echo "Testing the index: coupons for provider FAIRMONT in campaign CHRISTMAS2022"
awslocal dynamodb query \
    --region ${REGION} \
    --table-name "${TABLE_NAME}" \
    --index-name "${INDEX_NAME}" \
    --key-condition-expression "provider_id = :p AND campaign_id = :c" \
    --expression-attribute-values '{":p":{"S":"FAIRMONT"},":c":{"S":"CHRISTMAS2022"}}' \
    --select COUNT
[ $? == 0 ] || fail 2 "Failed to query index"

echo "${INDEX_NAME} added successfully"
