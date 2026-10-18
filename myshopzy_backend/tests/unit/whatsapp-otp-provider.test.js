const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createWhatsAppOtpProvider,
  OtpDeliveryError,
} = require('../../src/modules/customer-auth/whatsapp-otp-provider');

const config = {
  whatsapp: {
    accessToken: 'server-side-test-token',
    phoneNumberId: '123456789',
    templateName: 'authentication_code',
    templateLanguage: 'en_US',
    graphApiVersion: 'v25.0',
  },
};

test('sends an authentication copy-code template and requires a message ID', async () => {
  let request;
  const provider = createWhatsAppOtpProvider({
    config,
    async fetchImpl(url, options) {
      request = { url, options };
      return {
        ok: true,
        async json() {
          return { messages: [{ id: 'wamid.test-message' }] };
        },
      };
    },
  });

  const messageId = await provider.send({
    phoneNumber: '919876543210',
    otp: '123456',
  });
  const body = JSON.parse(request.options.body);
  const components = body.template.components;

  assert.equal(messageId, 'wamid.test-message');
  assert.equal(
    request.url,
    'https://graph.facebook.com/v25.0/123456789/messages',
  );
  assert.equal(request.options.headers.Authorization, 'Bearer server-side-test-token');
  assert.equal(body.to, '919876543210');
  assert.deepEqual(components[0].parameters, [
    { type: 'text', text: '123456' },
  ]);
  assert.equal(components[1].sub_type, 'url');
  assert.deepEqual(components[1].parameters, [
    { type: 'text', text: '123456' },
  ]);
});

test('does not treat HTTP 200 without a Meta message ID as accepted', async () => {
  const provider = createWhatsAppOtpProvider({
    config,
    async fetchImpl() {
      return { ok: true, async json() { return {}; } };
    },
  });

  await assert.rejects(
    provider.send({ phoneNumber: '919876543210', otp: '123456' }),
    OtpDeliveryError,
  );
});

test('does not expose provider response details on rejection', async () => {
  const provider = createWhatsAppOtpProvider({
    config,
    async fetchImpl() {
      return {
        ok: false,
        async json() {
          return { error: { message: 'private provider response' } };
        },
      };
    },
  });

  await assert.rejects(
    provider.send({ phoneNumber: '919876543210', otp: '123456' }),
    (error) => {
      assert.equal(error.message.includes('private provider response'), false);
      return error instanceof OtpDeliveryError;
    },
  );
});
