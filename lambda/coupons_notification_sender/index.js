const AWS = require('aws-sdk');

const DEFAULT_TOPIC_ARN = 'arn:aws:sns:us-east-1:000000000000:coupons';
const REQUIRED_FIELDS = ['coupon_code', 'title', 'description'];

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

// API Gateway sends the request body as a JSON string in event.body.
// The sample input events have the fields at the top level.
function getPayload(event) {
  if (event && event.body) {
    const raw = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString('utf8') :
      event.body;
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  }
  return event;
}
// Same structure as samples/t5_sample_notification_message.txt
function buildMessage(coupon) {
  return [
    'Dear customer,',
    '',
    'We are glad to inform you that a new coupon is available in our system:',
    `Coupon code: ${coupon.coupon_code}`,
    `Title: ${coupon.title}`,
    `Description: ${coupon.description}`,
    '',
    'Enjoy,',
    'Ideal Trip Team',
    '',
  ].join('\n');
}

exports.handler = async function(event) {
  let coupon;
  try {
    coupon = getPayload(event);
  } catch (error) {
    return response(400, { status: 'error', message: 'Request body must be valid JSON' });
  }

  if (!coupon || typeof coupon !== 'object' || Array.isArray(coupon)) {
    return response(400, { status: 'error', message: 'Request body must be a JSON object' });
  }

  const missing = REQUIRED_FIELDS.filter((field) => typeof coupon[field] !== 'string' || !coupon[field]);
  if (missing.length > 0) {
    return response(400, { status: 'error', message: `Missing required fields: ${missing.join(', ')}` });
  }

  const endpoint = getEndpoint();
  const sns = new AWS.SNS(endpoint ? { endpoint } : {});

  try {
    const result = await sns.publish({
      TopicArn: process.env.TOPIC_ARN || DEFAULT_TOPIC_ARN,
      Subject: 'New coupon available',
      Message: buildMessage(coupon),
    }).promise();

    console.log(`Sent notification for coupon ${coupon.coupon_id || coupon.coupon_code} (${result.MessageId})`);

    return response(200, {
      status: 'success',
      messageId: result.MessageId,
    });
  } catch (error) {
    console.error('Failed to send notification:', error);
    return response(500, { status: 'error', message: 'Could not send notification' });
  }
};
