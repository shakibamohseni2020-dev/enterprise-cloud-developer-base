const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const { handler } = require('../index.js');
const sampleEvent = require('../../../samples/t4_sample_coupon_import_event.json');
const apiGatewayEvent = require('./import_event.json');

describe('Coupon import', () => {
  let puts;

  beforeEach(() => {
    puts = [];
    AWSMock.setSDKInstance(AWS);
    AWSMock.mock('S3', 'putObject', (params, callback) => {
      puts.push(params);
      callback(null, { ETag: '"abc"' });
    });
  });

  afterEach(() => {
    AWSMock.restore('S3');
  });

  test('Should store the sample coupon as <coupon_id>.json and return success', async () => {
    const response = await handler(sampleEvent, null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toStrictEqual({ status: 'success' });
    expect(puts).toHaveLength(1);
    expect(puts[0].Bucket).toBe('coupons');
    expect(puts[0].Key).toBe('319326de971100158f6fa0daeec978fba1f17e4b.json');
    expect(puts[0].ContentType).toBe('application/json');
    expect(JSON.parse(puts[0].Body)).toStrictEqual(sampleEvent);
  });

  test('Should store one file per coupon from the coupons field of an API Gateway body', async () => {
    const response = await handler(apiGatewayEvent, null);

    expect(response.statusCode).toBe(200);
    expect(puts.map((p) => p.Key).sort()).toStrictEqual([
      '3f656e5fad7aa840efa7ab8c40118f011b9b9b5b.json',
      '502a81d1564cf66c66e429d9e7c571f872151d2d.json',
    ]);
  });

  test('Should return 415 when the request is not JSON', async () => {
    const event = { ...apiGatewayEvent, headers: { 'Content-Type': 'text/csv' } };

    const response = await handler(event, null);

    expect(response.statusCode).toBe(415);
    expect(puts).toHaveLength(0);
  });

  test('Should accept a JSON content type with a charset', async () => {
    const event = { ...apiGatewayEvent, headers: { 'content-type': 'application/json; charset=utf-8' } };

    const response = await handler(event, null);

    expect(response.statusCode).toBe(200);
  });

  test('Should reject a coupon_id that could change the file path', async () => {
    const response = await handler({ coupon_id: '../other-bucket/evil' }, null);

    expect(response.statusCode).toBe(400);
    expect(puts).toHaveLength(0);
  });

  test('Should return 400 when there is no coupon_id', async () => {
    const response = await handler({ title: 'No id' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 for an empty coupons list', async () => {
    const response = await handler({ coupons: [] }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 for a body that is not JSON', async () => {
    const response = await handler({ ...apiGatewayEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 500 when S3 fails', async () => {
    AWSMock.restore('S3');
    AWSMock.mock('S3', 'putObject', (params, callback) => callback(new Error('S3 is down')));

    const response = await handler(sampleEvent, null);

    expect(response.statusCode).toBe(500);
  });
});
