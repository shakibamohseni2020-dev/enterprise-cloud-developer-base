#!/bin/bash

FUNCTION_NAME="coupons_list"
ROLE_ARN="arn:aws:iam::000000000000:role/coupons_lambda_role"
REGION="us-east-1"
PROJECT_DIR=$(pwd)
BUILD_DIR="${PROJECT_DIR}/build/${FUNCTION_NAME}"
ZIP_FILE="${PROJECT_DIR}/${FUNCTION_NAME}.zip"
SAMPLE_EVENT="${PROJECT_DIR}/lambda/${FUNCTION_NAME}/tests/api_gateway_event.json"

function fail() {
  echo $2
  exit $1
}

echo "Preparing clean build folder for ${FUNCTION_NAME}"
rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}"
cp ./lambda/${FUNCTION_NAME}/index.js ./lambda/${FUNCTION_NAME}/package.json ./lambda/${FUNCTION_NAME}/package-lock.json "${BUILD_DIR}/"
[ $? == 0 ] || fail 1 "Failed to copy source files"

echo "Installing production dependencies only (jest/eslint are left out of the package)"
NODE_ENV=production npm install --prefix "${BUILD_DIR}" --no-audit --no-fund
[ $? == 0 ] || fail 2 "Failed to install dependencies"
[ -d "${BUILD_DIR}/node_modules" ] && find "${BUILD_DIR}/node_modules" -type d -empty -delete

echo "Creating deployment package ${FUNCTION_NAME}.zip"
cd "${BUILD_DIR}"
zip -r "${ZIP_FILE}" .
[ $? == 0 ] || fail 3 "Failed to create deployment package"
cd "${PROJECT_DIR}"

if awslocal lambda get-function --region ${REGION} --function-name "${FUNCTION_NAME}" > /dev/null 2>&1; then
  echo "${FUNCTION_NAME} already exists, updating its code"
  awslocal lambda update-function-code \
      --region ${REGION} \
      --function-name "${FUNCTION_NAME}" \
      --zip-file fileb://${FUNCTION_NAME}.zip > /dev/null
  [ $? == 0 ] || fail 4 "Failed to update function"
else
  echo "Creating ${FUNCTION_NAME} function"
  awslocal lambda create-function \
      --region ${REGION} \
      --function-name "${FUNCTION_NAME}" \
      --runtime "nodejs14.x" \
      --zip-file fileb://${FUNCTION_NAME}.zip \
      --handler "index.handler" \
      --role "${ROLE_ARN}"
  [ $? == 0 ] || fail 4 "Failed to create function"
fi

echo "Waiting for function to become active"
for i in $(seq 1 30); do
  STATE=$(awslocal lambda get-function --region ${REGION} --function-name "${FUNCTION_NAME}" --query 'Configuration.State' --output text)
  [ "${STATE}" == "Active" ] && break
  sleep 2
done
echo "Function state: ${STATE}"

echo "Invoking ${FUNCTION_NAME} with a sample API Gateway event"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://${SAMPLE_EVENT} \
    ${FUNCTION_NAME}_output.json
[ $? == 0 ] || fail 5 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""
rm -f ${FUNCTION_NAME}_output.json

echo "${FUNCTION_NAME} function created successfully"
