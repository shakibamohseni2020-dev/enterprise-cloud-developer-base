const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const { handler } = require('../index.js');
const sampleEvent = require('./update_event.json');
const originalCoupon = require('../../../samples/t2_coupons_get_by_id_response.json');

function eventWithBody(body) {
  return { ...sampleEvent, body: JSON.stringify(body) };
}

describe('Coupon update', () => {

  beforeEach(() => {
    AWSMock.setSDKInstance(AWS);
  });

  afterEach(() => {
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('Should update the coupon and return the new version', async () => {
    let requestedParams;
    const updated = { ...originalCoupon, title: 'Save 30% on Fairmont hotels' };
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      requestedParams = params;
      callback(null, { Attributes: updated });
    });

    const response = await handler(eventWithBody({ title: 'Save 30% on Fairmont hotels' }), null);

    expect(requestedParams.TableName).toBe('coupons');
    expect(requestedParams.Key).toStrictEqual({ coupon_id: originalCoupon.coupon_id });
    expect(requestedParams.UpdateExpression).toBe('SET #f0 = :v0');
    expect(requestedParams.ExpressionAttributeNames).toStrictEqual({ '#f0': 'title' });
    expect(requestedParams.ExpressionAttributeValues).toStrictEqual({ ':v0': 'Save 30% on Fairmont hotels' });
    expect(requestedParams.ConditionExpression).toBe('attribute_exists(coupon_id)');
    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toStrictEqual(updated);
  });

  test('Should ignore fields that are not allowed, like coupon_id', async () => {
    let requestedParams;
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      requestedParams = params;
      callback(null, { Attributes: originalCoupon });
    });

    await handler(eventWithBody({ coupon_id: 'hacked', coupon_code: 'NEW20' }), null);

    expect(Object.values(requestedParams.ExpressionAttributeNames)).toStrictEqual(['coupon_code']);
  });

  test('Should return 404 when the coupon does not exist', async () => {
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      const error = new Error('The conditional request failed');
      error.code = 'ConditionalCheckFailedException';
      callback(error);
    });

    const event = { ...eventWithBody({ title: 'x' }), pathParameters: { id: 'does-not-exist' } };
    const response = await handler(event, null);

    expect(response.statusCode).toBe(404);
  });

  test('Should return 400 for invalid JSON', async () => {
    const response = await handler({ ...sampleEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 when there is nothing to update', async () => {
    const response = await handler(eventWithBody({ color: 'blue' }), null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 when no id is given', async () => {
    const response = await handler({ ...sampleEvent, pathParameters: null }, null);

    expect(response.statusCode).toBe(400);
  });
});
