const { handler } = require('../index.js');
const sampleEvent = require('../../../samples/t4_sample_coupon_import_presigned_url_event.json');
const apiGatewayEvent = require('./presigned_url_event.json');

describe('Coupon import pre-signed URL', () => {

  beforeAll(() => {
    process.env.AWS_ACCESS_KEY_ID = 'test';
    process.env.AWS_SECRET_ACCESS_KEY = 'test';
    process.env.AWS_REGION = 'us-east-1';
    process.env.AWS_ENDPOINT_URL = 'http://localhost:4566';
  });

  test('Should return a PUT URL for exactly the requested file', async () => {
    const response = await handler(sampleEvent, null);
    const body = JSON.parse(response.body);
    const url = new URL(body.url);

    expect(response.statusCode).toBe(200);
    expect(body.status).toBe('success');
    expect(body.filename).toBe('319326de971100158f6fa0daeec978fba1f17e4b.json');
    expect(body.expiresIn).toBe(300);
    expect(body.method).toBe('PUT');
    expect(body.contentType).toBe('application/json');
    expect(url.pathname).toBe('/coupons/319326de971100158f6fa0daeec978fba1f17e4b.json');
    expect(url.searchParams.get('X-Amz-Expires')).toBe('300');
    expect(url.searchParams.get('X-Amz-Signature')).toBeTruthy();
  });

  test('Should read the filename from an API Gateway event body', async () => {
    const response = await handler(apiGatewayEvent, null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body).filename).toBe('319326de971100158f6fa0daeec978fba1f17e4b.json');
  });

  test('Should return 400 when filename is missing', async () => {
    const response = await handler({}, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 for a filename with a path in it', async () => {
    const response = await handler({ filename: '../secrets/file.json' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 for a file that is not JSON', async () => {
    const response = await handler({ filename: 'coupons.exe' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 400 for a body that is not JSON', async () => {
    const response = await handler({ ...apiGatewayEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(400);
  });
});
