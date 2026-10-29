const AWS = require('aws-sdk');
// bcryptjs is a pure JavaScript bcrypt implementation. It reads the same
// $2a$12$... hashes (bcrypt, 12 salt rounds) stored in the users table,
// without needing a native build for the Lambda runtime.
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const USERS_TABLE = process.env.USERS_TABLE || 'users';
const EXPIRES_IN = 3600; // seconds

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

// API Gateway sends the credentials as a JSON string in event.body.
// The sample event (t3_sample_coupons_get_token_event.json) has them at the top level.
function getCredentials(event) {
  if (!event) {
    return {};
  }
  if (event.body) {
    const raw = event.isBase64Encoded ?
      Buffer.from(event.body, 'base64').toString('utf8') :
      event.body;
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  }
  return event;
}

const forbidden = () => response(403, { message: 'Invalid username or password' });

exports.handler = async function(event) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    console.error('JWT_SECRET is not configured');
    return response(500, { message: 'Token service is not configured' });
  }

  let credentials;
  try {
    credentials = getCredentials(event);
  } catch (error) {
    return forbidden();
  }

  const { username, password } = credentials || {};
  if (typeof username !== 'string' || typeof password !== 'string' || !username || !password) {
    return forbidden();
  }

  // Never log the password.
  console.log(`Token requested for user ${username}`);

  const endpoint = getEndpoint();
  const db = new AWS.DynamoDB.DocumentClient(endpoint ? { endpoint } : {});

  let user;
  try {
    const result = await db.get({
      TableName: USERS_TABLE,
      Key: { username },
    }).promise();
    user = result.Item;
  } catch (error) {
    console.error('Failed to read user:', error);
    return response(500, { message: 'Could not generate token' });
  }

  if (!user || !user.password) {
    return forbidden();
  }

  const passwordMatches = await bcrypt.compare(password, user.password);
  if (!passwordMatches) {
    return forbidden();
  }

  const token = jwt.sign({ sub: username }, secret, {
    algorithm: 'HS256',
    expiresIn: EXPIRES_IN,
  });

  return response(200, {
    token,
    expiresIn: EXPIRES_IN,
  });
};
