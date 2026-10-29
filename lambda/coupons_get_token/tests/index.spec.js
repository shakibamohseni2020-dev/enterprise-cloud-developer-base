const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const jwt = require('jsonwebtoken');
const { handler } = require('../index.js');
const sampleEvent = require('../../../samples/t3_sample_coupons_get_token_event.json');
const apiGatewayEvent = require('./get_token_event.json');

const SECRET = '0HXc4w5NEzA61HkV';
// tester1's stored hash from the users table (bcrypt, 12 rounds)
const TESTER1 = {
  username: 'tester1',
  password: '$2a$12$wCqYSCDDoHdlUCI7rBBHO..c4KleiSzZqH8NXMHdLIcLsVxFmvG7C',
};

function mockUsers(users) {
  AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
    const user = users.find((u) => u.username === params.Key.username);
    callback(null, user ? { Item: user } : {});
  });
}

describe('Coupon get token', () => {

  beforeEach(() => {
    process.env.JWT_SECRET = SECRET;
    AWSMock.setSDKInstance(AWS);
  });

  afterEach(() => {
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('Should return a token and expiresIn for the sample event', async () => {
    mockUsers([TESTER1]);

    const response = await handler(sampleEvent, null);
    const body = JSON.parse(response.body);

    expect(response.statusCode).toBe(200);
    expect(Object.keys(body).sort()).toStrictEqual(['expiresIn', 'token']);
    expect(body.expiresIn).toBe(3600);

    const claims = jwt.verify(body.token, SECRET);
    expect(claims.sub).toBe('tester1');
    expect(claims.exp - claims.iat).toBe(3600);
  });

  test('Should read credentials from an API Gateway event body', async () => {
    mockUsers([TESTER1]);

    const response = await handler(apiGatewayEvent, null);

    expect(response.statusCode).toBe(200);
  });

  test('Should return 403 for a wrong password', async () => {
    mockUsers([TESTER1]);

    const response = await handler({ username: 'tester1', password: 'wrong' }, null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 for an unknown user', async () => {
    mockUsers([TESTER1]);

    const response = await handler({ username: 'nobody', password: 'Pc4RM0AMKy5aSGfD' }, null);

    expect(response.statusCode).toBe(403);
  });

  test('Should return 403 when username or password is missing', async () => {
    mockUsers([TESTER1]);

    expect((await handler({ username: 'tester1' }, null)).statusCode).toBe(403);
    expect((await handler({}, null)).statusCode).toBe(403);
  });

  test('Should return 403 for a body that is not JSON', async () => {
    const response = await handler({ ...apiGatewayEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(403);
  });
});
