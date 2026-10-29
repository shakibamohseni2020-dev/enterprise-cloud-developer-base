const jwt = require('jsonwebtoken');

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  };
}

// Reads the token from the Authorization header ("Bearer <token>").
// Header names are case-insensitive, so check them that way.
function getToken(event) {
  const headers = (event && event.headers) || {};
  const key = Object.keys(headers).find((name) => name.toLowerCase() === 'authorization');
  if (!key || !headers[key]) {
    return null;
  }
  const value = String(headers[key]).trim();
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : value;
}

const forbidden = (message) => response(403, { message });

exports.handler = async function(event) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    console.error('JWT_SECRET is not configured');
    return forbidden('Token could not be validated');
  }

  const token = getToken(event);
  if (!token) {
    return forbidden('Missing authorization token');
  }

  let claims;
  try {
    claims = jwt.verify(token, secret, { algorithms: ['HS256'] });
  } catch (error) {
    console.log(`Token validation failed: ${error.message}`);
    return forbidden('Invalid or expired token');
  }

  return response(200, {
    status: 'success',
    user: claims.sub,
  });
};
