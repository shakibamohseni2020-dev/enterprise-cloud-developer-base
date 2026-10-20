const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const { handler } = require('../index.js');
const sampleEvent = require('./get_by_id_event.json');
const expectedCoupon = require('../../../samples/t2_coupons_get_by_id_response.json');

describe('Coupon get by id', () => {

  beforeEach(() => {
    AWSMock.setSDKInstance(AWS);
  });

  afterEach(() => {
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('Should return the coupon for the id in the path', async () => {
    let requestedParams;
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      requestedParams = params;
      callback(null, { Item: expectedCoupon });
    });

    const response = await handler(sampleEvent, null);

    expect(requestedParams).toStrictEqual({
      TableName: 'coupons',
      Key: { coupon_id: '319326de971100158f6fa0daeec978fba1f17e4b' },
    });
    expect(response.statusCode).toBe(200);
    expect(response.headers['Content-Type']).toBe('application/json');
    expect(JSON.parse(response.body)).toStrictEqual(expectedCoupon);
  });

  test('Should return 404 when the coupon does not exist', async () => {
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, {});
    });

    const event = { ...sampleEvent, pathParameters: { id: 'does-not-exist' } };
    const response = await handler(event, null);

    expect(response.statusCode).toBe(404);
  });

  test('Should return 400 when no id is given', async () => {
    const response = await handler({ pathParameters: null }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 500 when DynamoDB fails', async () => {
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(new Error('DynamoDB is down'));
    });

    const response = await handler(sampleEvent, null);

    expect(response.statusCode).toBe(500);
  });
});
