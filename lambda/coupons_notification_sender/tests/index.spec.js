const fs = require('fs');
const path = require('path');
const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const { handler } = require('../index.js');
const sampleInput = require('../../../samples/t5_sample_notification_input_event.json');
const apiGatewayEvent = require('./notification_input_event.json');

const template = fs.readFileSync(
  path.join(__dirname, '../../../samples/t5_sample_notification_message.txt'), 'utf8');

function expectedMessage(coupon) {
  return template
    .replace(/\r\n/g, '\n')
    .replace('<coupon-code>', coupon.coupon_code)
    .replace('<title>', coupon.title)
    .replace('<description>', coupon.description);
}

describe('Coupon notification sender', () => {
  let published;

  beforeEach(() => {
    published = [];
    AWSMock.setSDKInstance(AWS);
    AWSMock.mock('SNS', 'publish', (params, callback) => {
      published.push(params);
      callback(null, { MessageId: 'abc-123' });
    });
  });

  afterEach(() => {
    AWSMock.restore('SNS');
  });

  test('Should send the notification using the sample message structure', async () => {
    const response = await handler(sampleInput, null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toStrictEqual({ status: 'success', messageId: 'abc-123' });
    expect(published).toHaveLength(1);
    expect(published[0].TopicArn).toBe('arn:aws:sns:us-east-1:000000000000:coupons');
    expect(published[0].Message.trimEnd()).toBe(expectedMessage(sampleInput).trimEnd());
  });

  test('Should read the coupon from an API Gateway body', async () => {
    const response = await handler(apiGatewayEvent, null);

    expect(response.statusCode).toBe(200);
    expect(published[0].Message).toContain('Coupon code: SAVE20');
  });

  test('Should use the topic from TOPIC_ARN when set', async () => {
    process.env.TOPIC_ARN = 'arn:aws:sns:us-east-1:000000000000:other';

    await handler(sampleInput, null);
    delete process.env.TOPIC_ARN;

    expect(published[0].TopicArn).toBe('arn:aws:sns:us-east-1:000000000000:other');
  });

  test('Should return 400 when coupon details are missing', async () => {
    const response = await handler({ coupon_id: 'only-an-id' }, null);

    expect(response.statusCode).toBe(400);
    expect(published).toHaveLength(0);
  });

  test('Should return 400 for a body that is not JSON', async () => {
    const response = await handler({ ...apiGatewayEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 500 when SNS fails', async () => {
    AWSMock.restore('SNS');
    AWSMock.mock('SNS', 'publish', (params, callback) => callback(new Error('SNS is down')));

    const response = await handler(sampleInput, null);

    expect(response.statusCode).toBe(500);
  });
});
