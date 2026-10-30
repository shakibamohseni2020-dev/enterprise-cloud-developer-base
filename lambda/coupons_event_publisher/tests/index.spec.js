const AWS = require('aws-sdk');
const AWSMock = require('aws-sdk-mock');
const { handler } = require('../index.js');
const sampleInput = require('../../../samples/t5_sample_stream_input_event.json');
const expectedMessage = require('../../../samples/t5_sample_stream_message.json');
const apiGatewayEvent = require('./stream_input_event.json');

describe('Coupon event publisher', () => {
  let records;

  beforeEach(() => {
    records = [];
    AWSMock.setSDKInstance(AWS);
    AWSMock.mock('Kinesis', 'putRecord', (params, callback) => {
      records.push(params);
      callback(null, { ShardId: 'shardId-000000000002', SequenceNumber: '4960' });
    });
  });

  afterEach(() => {
    AWSMock.restore('Kinesis');
  });

  test('Should publish the sample message to the coupons stream', async () => {
    const response = await handler(sampleInput, null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toStrictEqual({
      status: 'success',
      shardId: 'shardId-000000000002',
      sequenceNumber: '4960',
    });
    expect(records).toHaveLength(1);
    expect(records[0].StreamName).toBe('coupons');
    expect(records[0].PartitionKey).toBe('319326de971100158f6fa0daeec978fba1f17e4b');
    // Same fields and order as t5_sample_stream_message.json
    expect(records[0].Data).toBe(JSON.stringify(expectedMessage));
  });

  test('Should leave provider_id and campaign_id out of the message', async () => {
    await handler(sampleInput, null);
    const message = JSON.parse(records[0].Data);

    expect(message.provider_id).toBeUndefined();
    expect(message.campaign_id).toBeUndefined();
  });

  test('Should read the event from an API Gateway body', async () => {
    const response = await handler(apiGatewayEvent, null);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(records[0].Data)).toStrictEqual(expectedMessage);
  });

  test('Should return 400 when required fields are missing', async () => {
    const response = await handler({ title: 'No ids' }, null);

    expect(response.statusCode).toBe(400);
    expect(records).toHaveLength(0);
  });

  test('Should return 400 for a body that is not JSON', async () => {
    const response = await handler({ ...apiGatewayEvent, body: '{not json' }, null);

    expect(response.statusCode).toBe(400);
  });

  test('Should return 500 when Kinesis fails', async () => {
    AWSMock.restore('Kinesis');
    AWSMock.mock('Kinesis', 'putRecord', (params, callback) => callback(new Error('Stream is down')));

    const response = await handler(sampleInput, null);

    expect(response.statusCode).toBe(500);
  });
});
