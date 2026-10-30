#!/bin/bash

STREAM_NAME="coupons"
SHARD_COUNT=5
REGION="us-east-1"

function fail() {
  echo $2
  exit $1
}

# 5 shards = up to 5,000 records/sec (5 MB/sec) in and 10 MB/sec out.
echo "Creating Kinesis stream ${STREAM_NAME} with ${SHARD_COUNT} shards"
awslocal kinesis create-stream \
    --region ${REGION} \
    --stream-name "${STREAM_NAME}" \
    --shard-count ${SHARD_COUNT}
[ $? == 0 ] || fail 1 "Failed to create stream"

echo "Waiting for stream to be active"
awslocal kinesis wait stream-exists --region ${REGION} --stream-name "${STREAM_NAME}"
[ $? == 0 ] || fail 2 "Stream did not become active"

awslocal kinesis describe-stream-summary \
    --region ${REGION} \
    --stream-name "${STREAM_NAME}" \
    --query 'StreamDescriptionSummary.{Status:StreamStatus,OpenShards:OpenShardCount,Arn:StreamARN}'
[ $? == 0 ] || fail 3 "Failed to describe stream"

echo "${STREAM_NAME} stream created successfully"
