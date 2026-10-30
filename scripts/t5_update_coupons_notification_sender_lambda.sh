#!/bin/bash

FUNCTION_NAME="coupons_notification_sender"
TOPIC_NAME="coupons"
REGION="us-east-1"
TOPIC_ARN="arn:aws:sns:${REGION}:000000000000:${TOPIC_NAME}"
ROLE_NAME="coupons_lambda_role"
ROLE_ARN="arn:aws:iam::000000000000:role/${ROLE_NAME}"
ROLE_POLICY_NAME="coupons_topic_publish"
PERMISSION_DESCRIPTION="publish to the ${TOPIC_NAME} topic"
ROLE_POLICY="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowPublishToCouponsTopic\",\"Effect\":\"Allow\",\"Action\":[\"sns:Publish\"],\"Resource\":[\"${TOPIC_ARN}\"]}]}"
ENVIRONMENT="Variables={TOPIC_ARN=${TOPIC_ARN}}"
PROJECT_DIR=$(pwd)
BUILD_DIR="${PROJECT_DIR}/build/${FUNCTION_NAME}"
ZIP_FILE="${PROJECT_DIR}/${FUNCTION_NAME}.zip"

function fail() {
  echo $2
  exit $1
}

function wait_for_update() {
  for i in $(seq 1 30); do
    STATUS=$(awslocal lambda get-function --region ${REGION} --function-name "${FUNCTION_NAME}" --query 'Configuration.LastUpdateStatus' --output text)
    [ "${STATUS}" == "Successful" ] && return 0
    sleep 2
  done
  return 1
}

echo "Giving ${ROLE_NAME} permission: ${PERMISSION_DESCRIPTION}"
awslocal iam put-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name "${ROLE_POLICY_NAME}" \
    --policy-document "${ROLE_POLICY}"
[ $? == 0 ] || fail 1 "Failed to add permission to role"

echo "Preparing clean build folder for ${FUNCTION_NAME}"
rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}"
cp ./lambda/${FUNCTION_NAME}/index.js ./lambda/${FUNCTION_NAME}/package.json ./lambda/${FUNCTION_NAME}/package-lock.json "${BUILD_DIR}/"
[ $? == 0 ] || fail 2 "Failed to copy source files"

# aws-sdk comes with the nodejs14.x runtime, so only production
# dependencies are packaged (jest/eslint/aws-sdk-mock are left out).
echo "Installing production dependencies only"
NODE_ENV=production npm install --prefix "${BUILD_DIR}" --no-audit --no-fund
[ $? == 0 ] || fail 3 "Failed to install dependencies"
[ -d "${BUILD_DIR}/node_modules" ] && find "${BUILD_DIR}/node_modules" -type d -empty -delete

echo "Creating deployment package ${FUNCTION_NAME}.zip"
cd "${BUILD_DIR}"
zip -qr "${ZIP_FILE}" .
[ $? == 0 ] || fail 4 "Failed to create deployment package"
cd "${PROJECT_DIR}"

echo "Updating ${FUNCTION_NAME} code"
awslocal lambda update-function-code \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --zip-file fileb://${FUNCTION_NAME}.zip > /dev/null
[ $? == 0 ] || fail 5 "Failed to update function code"
wait_for_update || fail 6 "Function code update did not finish"

echo "Deploying ${FUNCTION_NAME} with ${ROLE_NAME}"
awslocal lambda update-function-configuration \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --role "${ROLE_ARN}" \
    --timeout 10 \
    --environment "${ENVIRONMENT}" > /dev/null
[ $? == 0 ] || fail 7 "Failed to update function configuration"
wait_for_update || fail 8 "Function configuration update did not finish"

echo "Invoking ${FUNCTION_NAME} with samples/t5_sample_notification_input_event.json"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://samples/t5_sample_notification_input_event.json \
    ${FUNCTION_NAME}_output.json > /dev/null
[ $? == 0 ] || fail 9 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""
grep -q '"statusCode":200' ${FUNCTION_NAME}_output.json || fail 10 "Notification was not sent"
rm -f ${FUNCTION_NAME}_output.json

echo "${FUNCTION_NAME} function updated successfully"
