const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const test = require('node:test');

const {
  verifyRazorpaySignature,
} = require('../../src/modules/payments/razorpay-signature');

const keySecret = 'backend-only-test-secret';
const orderId = 'order_test_123';
const paymentId = 'pay_test_456';

function createSignature() {
  return createHmac('sha256', keySecret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

test('verifies a Razorpay payment signature using the server-side secret', () => {
  assert.equal(
    verifyRazorpaySignature({
      orderId,
      paymentId,
      signature: createSignature(),
      keySecret,
    }),
    true,
  );
});

test('rejects invalid signatures and malformed inputs', () => {
  assert.equal(
    verifyRazorpaySignature({
      orderId,
      paymentId,
      signature: '0'.repeat(64),
      keySecret,
    }),
    false,
  );
  assert.equal(
    verifyRazorpaySignature({
      orderId,
      paymentId,
      signature: 'invalid',
      keySecret,
    }),
    false,
  );
  assert.equal(
    verifyRazorpaySignature({
      orderId,
      paymentId,
      signature: createSignature(),
      keySecret: '',
    }),
    false,
  );
});
