const jwt = require('jsonwebtoken');
const { handler } = require('../index.js');
const baseEvent = require('./no_token_event.json');

const SECRET = '0HXc4w5NEzA61HkV';

function eventWithAuth(value) {
  return { ...baseEvent, headers: { ...baseEvent.headers, Authorization: value } };
}

describe('Coupon to secure', () => {

  beforeEach(() => {
    process.env.JWT_SECRET = SECRET;
  });

  test('Should return success for a valid token', async () => {
    const token = jwt.sign({ sub: 'tester1' }, SECRET, { expiresIn: 3600 });

    const response = await handler(eventWithAuth(`Bearer ${token}`), null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toStrictEqual({ status: 'success', user: 'tester1' });
  });

  test('Should accept a lowercase authorization header', async () => {
    const token = jwt.sign({ sub: 'tester1' }, SECRET, { expiresIn: 3600 });
    const event = { ...baseEvent, headers: { authorization: `Bearer ${token}` } };

    const response = await handler(event, null);

    expect(response.statusCode).toBe(200);
  });

  test('Should return 403 when no token is sent', async () => {
    const response = await handler(baseEvent, null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 for a token signed with another secret', async () => {
    const token = jwt.sign({ sub: 'tester1' }, 'not-the-secret', { expiresIn: 3600 });

    const response = await handler(eventWithAuth(`Bearer ${token}`), null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 for an expired token', async () => {
    const token = jwt.sign({ sub: 'tester1', exp: Math.floor(Date.now() / 1000) - 60 }, SECRET);

    const response = await handler(eventWithAuth(`Bearer ${token}`), null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 for a garbage token', async () => {
    const response = await handler(eventWithAuth('Bearer abc.def.ghi'), null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 for a token using alg none', async () => {
    const token = jwt.sign({ sub: 'tester1' }, null, { algorithm: 'none' });

    const response = await handler(eventWithAuth(`Bearer ${token}`), null);

    expect(response.statusCode).toBe(403);
  });
});
