const AWS = require('aws-sdk');

const TABLE_NAME = process.env.COUPONS_TABLE || 'coupons';

// Inside LocalStack the SDK has to be pointed at LocalStack instead of real AWS.
function getEndpoint() {
  if (process.env.AWS_ENDPOINT_URL) {
    return process.env.AWS_ENDPOINT_URL;
  }
  if (process.env.LOCALSTACK_HOSTNAME) {
    return `http://${process.env.LOCALSTACK_HOSTNAME}:${process.env.EDGE_PORT || 4566}`;
  }
  return undefined;
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  };
}

exports.handler = async function(event) {
  console.log('Received event:', JSON.stringify(event));

  const id = event && event.pathParameters && event.pathParameters.id;
  if (!id) {
    return response(400, { message: 'Coupon id is required' });
  }

  const endpoint = getEndpoint();
  const db = new AWS.DynamoDB.DocumentClient(endpoint ? { endpoint } : {});

  try {
    const result = await db.get({
      TableName: TABLE_NAME,
      Key: { coupon_id: id },
    }).promise();

    if (!result.Item) {
      return response(404, { message: `Coupon ${id} not found` });
    }

    return response(200, result.Item);
  } catch (error) {
    console.error('Failed to get coupon:', error);
    return response(500, { message: 'Could not retrieve coupon' });
  }
};
