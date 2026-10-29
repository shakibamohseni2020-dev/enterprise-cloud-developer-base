#!/bin/bash

FUNCTION_NAME="coupons_to_secure"
REGION="us-east-1"
# Must match the secret coupons_get_token signs with.
JWT_SECRET="0HXc4w5NEzA61HkV"
PROJECT_DIR=$(pwd)
BUILD_DIR="${PROJECT_DIR}/build/${FUNCTION_NAME}"
ZIP_FILE="${PROJECT_DIR}/${FUNCTION_NAME}.zip"
NO_TOKEN_EVENT="${PROJECT_DIR}/lambda/${FUNCTION_NAME}/tests/no_token_event.json"

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

echo "Configuring ${FUNCTION_NAME} (secret)"
awslocal lambda update-function-configuration \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --timeout 10 \
    --environment "Variables={JWT_SECRET=${JWT_SECRET}}" > /dev/null
[ $? == 0 ] || fail 6 "Failed to update function configuration"
wait_for_update || fail 7 "Function configuration update did not finish"

echo "Invoking ${FUNCTION_NAME} without a token (expect 403)"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "${FUNCTION_NAME}" \
    --payload fileb://${NO_TOKEN_EVENT} \
    ${FUNCTION_NAME}_output.json > /dev/null
[ $? == 0 ] || fail 8 "Failed to invoke function"
cat ${FUNCTION_NAME}_output.json
echo ""

echo "Getting a token from coupons_get_token"
awslocal lambda invoke \
    --region ${REGION} \
    --function-name "coupons_get_token" \
    --payload fileb://samples/t3_sample_coupons_get_token_event.json \
    token_output.json > /dev/null
TOKEN=$(node -e "const r=require('./token_output.json'); console.log(JSON.parse(r.body).token || '')" 2>/dev/null)
rm -f token_output.json

if [ -n "${TOKEN}" ]; then
  echo "Invoking ${FUNCTION_NAME} with a valid token (expect 200)"
  echo "{\"headers\":{\"Authorization\":\"Bearer ${TOKEN}\"}}" > ${FUNCTION_NAME}_auth_event.json
  awslocal lambda invoke \
      --region ${REGION} \
      --function-name "${FUNCTION_NAME}" \
      --payload fileb://${FUNCTION_NAME}_auth_event.json \
      ${FUNCTION_NAME}_output.json > /dev/null
  [ $? == 0 ] || fail 9 "Failed to invoke function"
  cat ${FUNCTION_NAME}_output.json
  echo ""
  rm -f ${FUNCTION_NAME}_auth_event.json
else
  echo "Could not get a token (run t3_update_coupons_get_token_lambda.sh first)"
fi
rm -f ${FUNCTION_NAME}_output.json

echo "${FUNCTION_NAME} function updated successfully"
