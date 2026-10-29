#!/bin/bash

FUNCTION_NAME="coupons_get_token"
REGION="us-east-1"
USERS_TABLE="users"
# Secret given in the assessment. In production this would come from
# AWS Secrets Manager instead of being written in a script.
JWT_SECRET="0HXc4w5NEzA61HkV"
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

echo "Preparing clean build folder for ${FUNCTION_NAME}"
rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}"
cp ./lambda/${FUNCTION_NAME}/index.js ./lambda/${FUNCTION_NAME}/package.json ./lambda/${FUNCTION_NAME}/package-lock.json "${BUILD_DIR}/"
[ $? == 0 ] || fail 1 "Failed to copy source files"

# Only production dependencies go in the package (jsonwebtoken, bcryptjs).
# aws-sdk is provided by the nodejs14.x runtime; jest/eslint are left out.
echo "Installing production dependencies only"
NODE_ENV=production npm install --prefix "${BUILD_DIR}" --no-audit --no-fund
[ $? == 0 ] || fail 2 "Failed to install dependencies"
[ -d "${BUILD_DIR}/node_modules" ] && find "${BUILD_DIR}/node_modules" -type d -empty -delete

echo "Creating deployment package ${FUNCTION_NAME}.zip"
cd "${BUILD_DIR}"
zip -qr "${ZIP_FILE}" .
[ $? == 0 ] || fail 3 "Failed to create deployment package"
cd "${PROJECT_DIR}"

echo "Updating ${FUNCTION_NAME} code"
awslocal lambda update-function-code \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --zip-file fileb://${FUNCTION_NAME}.zip > /dev/null
[ $? == 0 ] || fail 4 "Failed to update function code"
wait_for_update || fail 5 "Function code update did not finish"

# bcrypt with 12 rounds takes a moment, so allow more than the 3s default.
echo "Configuring ${FUNCTION_NAME} (secret, users table, timeout)"
awslocal lambda update-function-configuration \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --timeout 10 \
    --memory-size 256 \
    --environment "Variables={JWT_SECRET=${JWT_SECRET},USERS_TABLE=${USERS_TABLE}}" > /dev/null
[ $? == 0 ] || fail 6 "Failed to update function configuration"
wait_for_update || fail 7 "Function configuration update did not finish"

echo "Invoking ${FUNCTION_NAME} with samples/t3_sample_coupons_get_token_event.json"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://samples/t3_sample_coupons_get_token_event.json \
    ${FUNCTION_NAME}_output.json > /dev/null
[ $? == 0 ] || fail 8 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""

echo "Invoking ${FUNCTION_NAME} with a wrong password (expect 403)"
echo '{"username":"tester1","password":"wrong-password"}' > ${FUNCTION_NAME}_bad_event.json
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://${FUNCTION_NAME}_bad_event.json \
    ${FUNCTION_NAME}_output.json > /dev/null
[ $? == 0 ] || fail 9 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""
rm -f ${FUNCTION_NAME}_output.json ${FUNCTION_NAME}_bad_event.json

echo "${FUNCTION_NAME} function updated successfully"
