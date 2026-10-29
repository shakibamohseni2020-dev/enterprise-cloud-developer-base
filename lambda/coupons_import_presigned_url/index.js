const AWS = require('aws-sdk');

const BUCKET_NAME = process.env.BUCKET_NAME || 'coupons';
const EXPIRES_IN = 300; // seconds

// Only plain JSON file names, e.g. 319326de971100158f6fa0daeec978fba1f17e4b.json
const SAFE_FILENAME = /^[A-Za-z0-9_-]+\.json$/;
// Uploads are JSON files; the client is told which Content-Type to send.
const FILE_CONTENT_TYPE = 'application/json';

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
  return new AWS.S3(endpoint ?
    { endpoint, s3ForcePathStyle: true, signatureVersion: 'v4' } :
    { signatureVersion: 'v4' });
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

function getPayload(event) {
  if (event && event.body) {
    const raw = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString('utf8') :
      event.body;
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  }
  return event;
}

exports.handler = async function(event) {
  let payload;
  try {
    payload = getPayload(event);
  } catch (error) {
    return response(400, { status: 'error', message: 'Request body must be valid JSON' });
  }

  const filename = payload && payload.filename;
  if (typeof filename !== 'string' || !SAFE_FILENAME.test(filename)) {
    return response(400, {
      status: 'error',
      message: 'filename must be a .json file name made of letters, numbers, - or _',
    });
  }

  const s3 = createS3();

  try {
    // The URL is signed for this exact bucket + key + PUT, so it can only
    // be used to upload the file named in the request.
    const url = await s3.getSignedUrlPromise('putObject', {
      Bucket: BUCKET_NAME,
      Key: filename,
      ContentType: FILE_CONTENT_TYPE,
      Expires: EXPIRES_IN,
    });

    return response(200, {
      status: 'success',
      url,
      filename,
      method: 'PUT',
      contentType: FILE_CONTENT_TYPE,
      expiresIn: EXPIRES_IN,
    });
  } catch (error) {
    console.error('Failed to create pre-signed URL:', error);
    return response(500, { status: 'error', message: 'Could not create upload URL' });
  }
};
