#!/bin/bash

API_NAME="coupons"
API_BASE_URL="http://localhost:4566"
REGION="us-east-1"
STAGE="local"

function fail() {
  echo $2
  exit 1
}

echo "Creating production policy"
awslocal iam create-policy --policy-name "coupons_production_policy" --policy-document file://scripts/coupons_production_policy.json
[ $? == 0 ] || fail 1 "Failed to create production policy"

echo "Creating production role for lambda functions"
awslocal iam create-role \
  --role-name "coupons_production_role" \
  --assume-role-policy-document \
  file://scripts/coupons_lambda_role_assume_role_policy.json
[ $? == 0 ] || fail 2 "Failed to create production role"

echo "Attaching policy to role"
awslocal iam attach-role-policy \
  --role-name "coupons_production_role" \
  --policy-arn "arn:aws:iam::000000000000:policy/coupons_production_policy"
[ $? == 0 ] || fail 3 "Failed to create policy attachment"

echo "Creating DynamoDB Table for users"
awslocal dynamodb create-table \
    --table-name "users" \
    --attribute-definitions AttributeName=username,AttributeType=S \
    --key-schema AttributeName=username,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
[ $? == 0 ] || fail 1 "Failed to create DynamoDB Table"

echo "Adding sample user to database"
awslocal dynamodb put-item \
    --table-name "users" \
    --item '{"username":{"S":"tester1"},"password":{"S":"$2a$12$wCqYSCDDoHdlUCI7rBBHO..c4KleiSzZqH8NXMHdLIcLsVxFmvG7C"}}' \
    --return-consumed-capacity TOTAL \
    --return-item-collection-metrics SIZE
[ $? == 0 ] || fail 1 "Failed to add sample user to database"
echo "Plaintext: Pc4RM0AMKy5aSGfD"

echo "Adding sample user to database"
awslocal dynamodb put-item \
    --table-name "users" \
    --item '{"username":{"S":"tester2"},"password":{"S":"$2a$12$KWfAWTZM9npRke3tWZcoE.f1fD6jNTfYwYeZv4A7WTBOl1PCYxlnW"}}' \
    --return-consumed-capacity TOTAL \
    --return-item-collection-metrics SIZE
[ $? == 0 ] || fail 1 "Failed to add sample user to database"
echo "Plaintext: 4LWs6xnc1t32BzXA"

echo "Creating lambda functions"
echo "Installing dependencies for coupons_get_by_id"
npm install --prefix ./lambda/coupons_get_by_id
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_get_by_id function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_get_by_id
zip -r "${PROJECT_DIR}/coupons_get_by_id.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_get_by_id function"
awslocal lambda create-function \
    --function-name "coupons_get_by_id" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_get_by_id.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_get_by_id function created successfully"

echo "Installing dependencies for coupons_update"
npm install --prefix ./lambda/coupons_update
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_update function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_update
zip -r "${PROJECT_DIR}/coupons_update.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_update function"
awslocal lambda create-function \
    --function-name "coupons_update" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_update.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_get_by_id function created successfully"

echo "Installing dependencies for coupons_get_token"
npm install --prefix ./lambda/coupons_get_token
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_get_token function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_get_token
zip -r "${PROJECT_DIR}/coupons_get_token.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_get_token function"
awslocal lambda create-function \
    --function-name "coupons_get_token" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_get_token.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_get_token function created successfully"

echo "Installing dependencies for coupons_to_secure"
npm install --prefix ./lambda/coupons_to_secure
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_to_secure function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_to_secure
zip -r "${PROJECT_DIR}/coupons_to_secure.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_to_secure function"
awslocal lambda create-function \
    --function-name "coupons_to_secure" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_to_secure.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_to_secure function created successfully"

echo "Installing dependencies for coupons_import"
npm install --prefix ./lambda/coupons_import
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_import function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_import
zip -r "${PROJECT_DIR}/coupons_import.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_import function"
awslocal lambda create-function \
    --function-name "coupons_import" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_import.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_import function created successfully"

echo "Installing dependencies for coupons_import_presigned_url"
npm install --prefix ./lambda/coupons_import_presigned_url
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_import_presigned_url function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_import_presigned_url
zip -r "${PROJECT_DIR}/coupons_import_presigned_url.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_import_presigned_url function"
awslocal lambda create-function \
    --function-name "coupons_import_presigned_url" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_import_presigned_url.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_import_presigned_url function created successfully"

echo "Installing dependencies for coupons_event_publisher"
npm install --prefix ./lambda/coupons_event_publisher
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_event_publisher function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_event_publisher
zip -r "${PROJECT_DIR}/coupons_event_publisher.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_event_publisher function"
awslocal lambda create-function \
    --function-name "coupons_event_publisher" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_event_publisher.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_event_publisher function created successfully"

echo "Installing dependencies for coupons_notification_sender"
npm install --prefix ./lambda/coupons_notification_sender
[ $? == 0 ] || fail 1 "Failed to install dependencies"

echo "Creating deployment package for coupons_notification_sender function"
PROJECT_DIR=$(pwd)
cd ./lambda/coupons_notification_sender
zip -r "${PROJECT_DIR}/coupons_notification_sender.zip" .
cd $PROJECT_DIR
[ $? == 0 ] || fail 2 "Failed to create deployment package"

echo "Creating coupons_notification_sender function"
awslocal lambda create-function \
    --function-name "coupons_notification_sender" \
    --runtime "nodejs14.x" \
    --zip-file fileb://coupons_notification_sender.zip \
    --handler "index.handler" \
    --role "arn:aws:iam::000000000000:role/coupons_production_role"
[ $? == 0 ] || fail 3 "Failed to create function"
echo "coupons_notification_sender function created successfully"

echo "Creating REST API"
awslocal apigateway create-rest-api \
  --region us-east-1 \
  --name "${API_NAME}" \
  --binary-media-types '*/*'
[ $? == 0 ] || fail 1 "Failed to create Api"

echo "Retrieving Api id"
API_ID=$(awslocal apigateway get-rest-apis --region ${REGION} --query "items[?name==\`${API_NAME}\`].id" --output text)
[ $? == 0 ] || fail 2 "Failed to retrieve Api id"
echo "Api id ${API_ID}"

echo "Retrieving root resource id"
ROOT_RESOURCE_ID=$(awslocal apigateway get-resources --rest-api-id ${API_ID} --query 'items[?path==`/`].id' --output text --region ${REGION})
[ $? == 0 ] || fail 3 "Failed to retrieve root resource id"
echo "Root resource id ${ROOT_RESOURCE_ID}"

echo "Creating coupons resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_RESOURCE_ID} \
    --path-part "coupons"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving coupons resource id"
COUPONS_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "coupons resource id ${COUPONS_RESOURCE_ID}"

echo "Creating coupons/{id} resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "{id}"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving coupons/{id} resource id"
COUPONS_ID_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/{id}`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "coupons resource/{id} id ${COUPONS_ID_RESOURCE_ID}"

echo "Creating GET method"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_ID_RESOURCE_ID} \
    --request-parameters method.request.path.id=true \
    --http-method GET \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create GET method"

echo "Retrieving coupons_get_by_id lambda Arn"
COUPONS_GET_BY_ID_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_get_by_id\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_get_by_id lambda Arn ${COUPONS_GET_BY_ID_LAMBDA_ARN}"

echo "Creating integration for coupons_get_by_id"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_ID_RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_GET_BY_ID_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating PUT method"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_ID_RESOURCE_ID} \
    --request-parameters method.request.path.id=true \
    --http-method PUT \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create GET method"

echo "Retrieving coupons_update lambda Arn"
COUPONS_UPDATE_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_update\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_update lambda Arn ${COUPONS_UPDATE_LAMBDA_ARN}"

echo "Creating integration for coupons_update"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_ID_RESOURCE_ID} \
    --http-method PUT \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_UPDATE_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating token resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_RESOURCE_ID} \
    --path-part "token"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving token resource id"
TOKEN_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/token`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "token resource id ${TOKEN_RESOURCE_ID}"

echo "Creating POST method for token resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${TOKEN_RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create POST method"

echo "Retrieving coupons_get_token lambda Arn"
COUPONS_GET_TOKEN_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_get_token\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_get_token lambda Arn ${COUPONS_GET_TOKEN_LAMBDA_ARN}"

echo "Creating integration for coupons_get_token"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${TOKEN_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_GET_TOKEN_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating /coupons/to_secure resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "to_secure"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving /coupons/to_secure resource id"
COUPONS_TO_SECURE_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/to_secure`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "/coupons/to_secure resource id ${COUPONS_TO_SECURE_RESOURCE_ID}"

echo "Creating GET method for token resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_TO_SECURE_RESOURCE_ID} \
    --http-method GET \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create GET method"

echo "Retrieving coupons_get_token lambda Arn"
COUPONS_TO_SECURE_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_to_secure\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_to_secure lambda Arn ${COUPONS_TO_SECURE_LAMBDA_ARN}"

echo "Creating integration for coupons_to_secure"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_TO_SECURE_RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_TO_SECURE_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating /coupons/import resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "import"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving /coupons/import resource id"
COUPONS_IMPORT_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/import`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "/coupons/import resource id ${COUPONS_IMPORT_RESOURCE_ID}"

echo "Creating POST method for import resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_IMPORT_RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create POST method"

echo "Retrieving coupons_import lambda Arn"
COUPONS_IMPORT_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_import\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_import lambda Arn ${COUPONS_IMPORT_LAMBDA_ARN}"

echo "Creating integration for coupons_import"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_IMPORT_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_IMPORT_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating /coupons/import_presigned_url resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "import_presigned_url"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving /coupons/import_presigned_url resource id"
COUPONS_IMPORT_PRESIGNED_URL_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/import_presigned_url`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "/coupons/import_presigned_url resource id ${COUPONS_IMPORT_PRESIGNED_URL_RESOURCE_ID}"

echo "Creating POST method for /coupons/import_presigned_url resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_IMPORT_PRESIGNED_URL_RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create POST method"

echo "Retrieving coupons_import_presigned_url lambda Arn"
COUPONS_IMPORT_PRESIGNED_URL_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_import_presigned_url\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_import_presigned_url lambda Arn ${COUPONS_IMPORT_PRESIGNED_URL_LAMBDA_ARN}"

echo "Creating integration for coupons_import_presigned_url"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_IMPORT_PRESIGNED_URL_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_IMPORT_PRESIGNED_URL_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating /coupons/event_publisher resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "event_publisher"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving /coupons/event_publisher resource id"
COUPONS_EVENT_PUBLISHER_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/event_publisher`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "/coupons/event_publisher resource id ${COUPONS_EVENT_PUBLISHER_RESOURCE_ID}"

echo "Creating POST method for /coupons/event_publisher resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_EVENT_PUBLISHER_RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create POST method"

echo "Retrieving coupons_event_publisher lambda Arn"
COUPONS_EVENT_PUBLISHER_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_event_publisher\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_event_publisher lambda Arn ${COUPONS_EVENT_PUBLISHER_LAMBDA_ARN}"

echo "Creating integration for coupons_event_publisher"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_EVENT_PUBLISHER_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_EVENT_PUBLISHER_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating /coupons/notification_sender resource"
awslocal apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${COUPONS_RESOURCE_ID} \
    --path-part "notification_sender"
[ $? == 0 ] || fail 4 "Failed to create resource"

echo "Retrieving /coupons/notification_sender resource id"
COUPONS_NOTIFICATION_SENDER_RESOURCE_ID=$(awslocal apigateway get-resources --region ${REGION} --rest-api-id ${API_ID} --query 'items[?path==`/coupons/notification_sender`].id' --output text)
[ $? == 0 ] || fail 5 "Failed to retrieve resource id"
echo "/coupons/notification_sender resource id ${COUPONS_NOTIFICATION_SENDER_RESOURCE_ID}"

echo "Creating POST method for /coupons/notification_sender resource"
awslocal apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_NOTIFICATION_SENDER_RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE"
[ $? == 0 ] || fail 6 "Failed to create POST method"

echo "Retrieving coupons_notification_sender lambda Arn"
COUPONS_NOTIFICATION_SENDER_LAMBDA_ARN=$(awslocal lambda list-functions --region ${REGION} --query "Functions[?FunctionName==\`coupons_notification_sender\`].FunctionArn" --output text)
[ $? == 0 ] || fail 7 "Failed to retrieve lambda ARN"
echo "coupons_notification_sender lambda Arn ${COUPONS_NOTIFICATION_SENDER_LAMBDA_ARN}"

echo "Creating integration for coupons_notification_sender"
awslocal apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${COUPONS_NOTIFICATION_SENDER_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${COUPONS_NOTIFICATION_SENDER_LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH
[ $? == 0 ] || fail 8 "Failed to create integration"

echo "Creating deployment"
awslocal apigateway create-deployment \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --stage-name ${STAGE}
[ $? == 0 ] || fail 9 "Failed to create deployment"

ENDPOINT="http://${API_ID}.execute-api.localhost.localstack.cloud:4566/local/<resource-id>"

echo "API URL: ${ENDPOINT}"
echo "API ID: ${API_ID}"

echo "All tasks completed successfully"
