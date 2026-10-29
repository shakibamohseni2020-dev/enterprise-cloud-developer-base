const AWS = require('aws-sdk');

const BUCKET_NAME = process.env.BUCKET_NAME || 'coupons';

// coupon_id becomes the file name, so only allow safe characters
// (no slashes or dots that could write outside the expected key).
const SAFE_ID = /^[A-Za-z0-9_-]+$/;

// Imports are stored as JSON files, so only JSON requests are accepted.
const FILE_CONTENT_TYPE = 'application/json';
const FILE_EXTENSION = '.json';

function getEndpoint() {
  if (process.env.AWS_ENDPOINT_URL) {
    return process.env.AWS_ENDPOINT_URL;
  }
  if (process.env.LOCALSTACK_HOSTNAME) {
    return `http://${process.env.LOCALSTACK_HOSTNAME}:${process.env.EDGE_PORT || 4566}`;
  }
  return undefined;
}

function createS3() {
  const endpoint = getEndpoint();
  return new AWS.S3(endpoint ? { endpoint, s3ForcePathStyle: true } : {});
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
// The sample event (t4_sample_coupon_import_event.json) is the coupon itself.
function getPayload(event) {
  if (event && event.body) {
    const raw = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString('utf8') :
      event.body;
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  }
  return event;
}

// Accepts either { coupons: [ ...coupons ] } or a single coupon object.
function getCoupons(payload) {
  if (payload && Array.isArray(payload.coupons)) {
    return payload.coupons;
  }
  if (payload && typeof payload === 'object' && !Array.isArray(payload)) {
    return [payload];
  }
  return [];
}

// Returns the request's Content-Type (header names are case-insensitive),
// or null when the event did not come with headers (e.g. a direct invoke).
function getContentType(event) {
  const headers = (event && event.headers) || {};
  const key = Object.keys(headers).find((name) => name.toLowerCase() === 'content-type');
  return key ? String(headers[key]).split(';')[0].trim().toLowerCase() : null;
}

exports.handler = async function(event) {
  const contentType = getContentType(event);
  if (contentType && contentType !== FILE_CONTENT_TYPE) {
    return response(415, {
      status: 'error',
      message: `Unsupported file type ${contentType}. Coupons must be sent as ${FILE_CONTENT_TYPE}`,
    });
  }

  let payload;
  try {
    payload = getPayload(event);
  } catch (error) {
    return response(400, { status: 'error', message: 'Request body must be valid JSON' });
  }

  const coupons = getCoupons(payload);
  if (coupons.length === 0) {
    return response(400, { status: 'error', message: 'No coupons to import' });
  }

  const invalid = coupons.find((coupon) =>
    !coupon || typeof coupon.coupon_id !== 'string' || !SAFE_ID.test(coupon.coupon_id));
  if (invalid) {
    return response(400, {
      status: 'error',
      message: 'Every coupon needs a coupon_id made of letters, numbers, - or _',
    });
  }

  const s3 = createS3();

  try {
    await Promise.all(coupons.map((coupon) => s3.putObject({
      Bucket: BUCKET_NAME,
      Key: `${coupon.coupon_id}${FILE_EXTENSION}`,
      Body: JSON.stringify(coupon, null, 2),
      ContentType: FILE_CONTENT_TYPE,
    }).promise()));
  } catch (error) {
    console.error('Failed to store coupon import file:', error);
    return response(500, { status: 'error', message: 'Could not import coupons' });
  }

  console.log(`Imported ${coupons.map((c) => `${c.coupon_id}${FILE_EXTENSION}`).join(', ')} into ${BUCKET_NAME}`);

  return response(200, { status: 'success' });
};
