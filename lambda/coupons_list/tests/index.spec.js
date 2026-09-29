const { handler } = require('../index.js');
const sampleEvent = require('./api_gateway_event.json');
const expectedCoupons = require('../../../samples/t1_sample_coupons_list_response.json');

describe('Coupon list', () => {

  test('Should return status code 200', async () => {
    const response = await handler(sampleEvent, null);

    expect(response.statusCode).toBe(200);
  });

  test('Should return a JSON content type header', async () => {
    const response = await handler(sampleEvent, null);

    expect(response.headers['Content-Type']).toBe('application/json');
  });

  test('Should return the sample coupons list', async () => {
    const response = await handler(sampleEvent, null);
    const responseParsed = JSON.parse(response.body);

    expect(responseParsed).toStrictEqual(expectedCoupons);
  });

  test('Each coupon should have all the required fields', async () => {
    const response = await handler(sampleEvent, null);
    const coupons = JSON.parse(response.body);
    const fields = ['coupon_id', 'title', 'description', 'coupon_code',
      'campaign_id', 'provider_id', 'provider_name', 'start_date', 'end_date'];

    expect(coupons).toHaveLength(3);
    coupons.forEach((coupon) => {
      fields.forEach((field) => expect(coupon).toHaveProperty(field));
    });
  });

  test('Should still work with an empty event', async () => {
    const response = await handler({}, null);

    expect(response.statusCode).toBe(200);
    expect(Array.isArray(JSON.parse(response.body))).toBe(true);
  });
});
