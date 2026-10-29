const { createHmac, timingSafeEqual } = require('node:crypto');

function verifyRazorpaySignature({
  orderId,
  paymentId,
  signature,
  keySecret,
}) {
  if (
    typeof orderId !== 'string' ||
    typeof paymentId !== 'string' ||
    typeof keySecret !== 'string' ||
    keySecret.length === 0 ||
    typeof signature !== 'string' ||
    !/^[a-f0-9]{64}$/i.test(signature)
  ) {
    return false;
  }

  const expected = createHmac('sha256', keySecret)
    .update(`${orderId}|${paymentId}`)
    .digest();
  const received = Buffer.from(signature, 'hex');
  return received.length === expected.length && timingSafeEqual(received, expected);
}

module.exports = { verifyRazorpaySignature };