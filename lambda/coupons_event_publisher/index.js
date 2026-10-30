const AWS = require('aws-sdk');

const STREAM_NAME = process.env.STREAM_NAME || 'coupons';

// Fields sent to the stream, in the order of t5_sample_stream_message.json.
// provider_id and campaign_id from the input are not part of the message.
const MESSAGE_FIELDS = [
  'event_id',
  'event_type',
  'coupon_id',
  'title',
  'description',
  'coupon_code',
  'start_date',
  'end_date',
];
const REQUIRED_FIELDS = ['event_id', 'event_type', 'coupon_id'];

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
function buildMessage(input) {
  const message = {};
  MESSAGE_FIELDS.forEach((field) => {
    if (input[field] !== undefined) {
      message[field] = input[field];
    }
  });
  return message;
}

exports.handler = async function(event) {
  let input;
  try {
    input = getPayload(event);
  } catch (error) {
    return response(400, { status: 'error', message: 'Request body must be valid JSON' });
  }

  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return response(400, { status: 'error', message: 'Request body must be a JSON object' });
  }

  const missing = REQUIRED_FIELDS.filter((field) => typeof input[field] !== 'string' || !input[field]);
  if (missing.length > 0) {
    return response(400, { status: 'error', message: `Missing required fields: ${missing.join(', ')}` });
  }

  const message = buildMessage(input);
  const endpoint = getEndpoint();
  const kinesis = new AWS.Kinesis(endpoint ? { endpoint } : {});

  try {
    // Using coupon_id as the partition key keeps every event for the same
    // coupon on the same shard, so consumers read them in order.
    const result = await kinesis.putRecord({
      StreamName: STREAM_NAME,
      PartitionKey: message.coupon_id,
      Data: JSON.stringify(message),
    }).promise();

    console.log(`Published ${message.event_type} for ${message.coupon_id} to ${result.ShardId}`);

    return response(200, {
      status: 'success',
      shardId: result.ShardId,
      sequenceNumber: result.SequenceNumber,
    });
  } catch (error) {
    console.error('Failed to publish event:', error);
    return response(500, { status: 'error', message: 'Could not publish event' });
  }
};
