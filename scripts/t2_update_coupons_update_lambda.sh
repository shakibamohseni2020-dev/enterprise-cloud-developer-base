#!/bin/bash

FUNCTION_NAME="coupons_update"
ROLE_ARN="arn:aws:iam::000000000000:role/coupons_lambda_role"
REGION="us-east-1"
PROJECT_DIR=$(pwd)
BUILD_DIR="${PROJECT_DIR}/build/${FUNCTION_NAME}"
ZIP_FILE="${PROJECT_DIR}/${FUNCTION_NAME}.zip"
SAMPLE_EVENT="${PROJECT_DIR}/lambda/${FUNCTION_NAME}/tests/update_event.json"

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

echo "Preparing clean build folder for ${FUNCTION_NAME}"
rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}"
cp ./lambda/${FUNCTION_NAME}/index.js ./lambda/${FUNCTION_NAME}/package.json ./lambda/${FUNCTION_NAME}/package-lock.json "${BUILD_DIR}/"
[ $? == 0 ] || fail 1 "Failed to copy source files"

# aws-sdk is provided by the nodejs14.x Lambda runtime, so only
# production dependencies go in the package (no jest/eslint/aws-sdk).
echo "Installing production dependencies only"
NODE_ENV=production npm install --prefix "${BUILD_DIR}" --no-audit --no-fund
[ $? == 0 ] || fail 2 "Failed to install dependencies"
[ -d "${BUILD_DIR}/node_modules" ] && find "${BUILD_DIR}/node_modules" -type d -empty -delete

echo "Creating deployment package ${FUNCTION_NAME}.zip"
cd "${BUILD_DIR}"
zip -r "${ZIP_FILE}" .
[ $? == 0 ] || fail 3 "Failed to create deployment package"
cd "${PROJECT_DIR}"

echo "Updating ${FUNCTION_NAME} code"
awslocal lambda update-function-code \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --zip-file fileb://${FUNCTION_NAME}.zip > /dev/null
[ $? == 0 ] || fail 4 "Failed to update function code"
wait_for_update || fail 5 "Function code update did not finish"

echo "Pointing ${FUNCTION_NAME} at coupons_lambda_role and the coupons table"
awslocal lambda update-function-configuration \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --role "${ROLE_ARN}" \
    --timeout 10 \
    --environment "Variables={COUPONS_TABLE=coupons}" > /dev/null
[ $? == 0 ] || fail 6 "Failed to update function configuration"
wait_for_update || fail 7 "Function configuration update did not finish"

echo "Invoking ${FUNCTION_NAME} with a sample API Gateway event"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://${SAMPLE_EVENT} \
    ${FUNCTION_NAME}_output.json
[ $? == 0 ] || fail 8 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""
rm -f ${FUNCTION_NAME}_output.json

echo "${FUNCTION_NAME} function updated successfully"
