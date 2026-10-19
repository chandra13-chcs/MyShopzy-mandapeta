const assert = require('node:assert/strict');
const test = require('node:test');

const { isOpenNow } = require('../../src/modules/shared/store-hours');

const shop = { timezone: 'Asia/Kolkata' };

test('uses default hours in Asia/Kolkata and includes opening time', () => {
  assert.deepEqual(isOpenNow(shop, new Date('2025-01-01T01:30:00.000Z')), {
    open: true,
    opensAt: '07:00',
    closesAt: '23:00',
  });
});

test('is open at 22:59 and closed at 23:00 and midnight', () => {
  assert.equal(isOpenNow(shop, new Date('2025-01-01T17:29:00.000Z')).open, true);
  assert.equal(isOpenNow(shop, new Date('2025-01-01T17:30:00.000Z')).open, false);
  assert.equal(isOpenNow(shop, new Date('2025-01-01T18:30:00.000Z')).open, false);
});

test('uses a shop override and its timezone', () => {
  const result = isOpenNow(
    { timezone: 'UTC', operating_details: { open: '09:00', close: '17:00' } },
    new Date('2025-01-01T09:00:00.000Z'),
  );

  assert.deepEqual(result, {
    open: true,
    opensAt: '09:00',
    closesAt: '17:00',
  });
});
