const AWS = require('aws-sdk');

const TABLE_NAME = process.env.COUPONS_TABLE || 'coupons';

// Fields a client is allowed to change. coupon_id is the key, so it can't be updated.
const UPDATABLE_FIELDS = [
  'title',
  'description',
  'coupon_code',
  'campaign_id',
  'provider_id',
  'provider_name',
  'start_date',
  'end_date',
];

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

function parseBody(event) {
  if (!event.body) {
    return null;
  }
  const raw = event.isBase64Encoded ?
    Buffer.from(event.body, 'base64').toString('utf8') :
    event.body;
  return typeof raw === 'string' ? JSON.parse(raw) : raw;
}

exports.handler = async function(event) {
  console.log('Received event:', JSON.stringify(event));

  const id = event && event.pathParameters && event.pathParameters.id;
  if (!id) {
    return response(400, { message: 'Coupon id is required' });
  }

  let changes;
  try {
    changes = parseBody(event);
  } catch (error) {
    return response(400, { message: 'Request body must be valid JSON' });
  }
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) {
    return response(400, { message: 'Request body must be a JSON object' });
  }

  const fields = Object.keys(changes).filter((field) => UPDATABLE_FIELDS.includes(field));
  if (fields.length === 0) {
    return response(400, {
      message: `Nothing to update. Allowed fields: ${UPDATABLE_FIELDS.join(', ')}`,
    });
  }

  const names = {};
  const values = {};
  const sets = fields.map((field, i) => {
    names[`#f${i}`] = field;
    values[`:v${i}`] = changes[field];
    return `#f${i} = :v${i}`;
  });

  const endpoint = getEndpoint();
  const db = new AWS.DynamoDB.DocumentClient(endpoint ? { endpoint } : {});

  try {
    const result = await db.update({
      TableName: TABLE_NAME,
      Key: { coupon_id: id },
      UpdateExpression: `SET ${sets.join(', ')}`,
      ConditionExpression: 'attribute_exists(coupon_id)',
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values,
      ReturnValues: 'ALL_NEW',
    }).promise();

    return response(200, result.Attributes);
  } catch (error) {
    if (error.code === 'ConditionalCheckFailedException') {
      return response(404, { message: `Coupon ${id} not found` });
    }
    console.error('Failed to update coupon:', error);
    return response(500, { message: 'Could not update coupon' });
  }
};
