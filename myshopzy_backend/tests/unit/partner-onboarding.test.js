const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createPartnerWithDefaults,
} = require('../../src/modules/partner-types/onboarding-service');

function createPool({ failOnCategory = false } = {}) {
  const calls = [];
  let released = false;
  return {
    calls,
    get released() {
      return released;
    },
    async connect() {
      return {
        async query(sql, params = []) {
          const normalizedSql = sql.replace(/\s+/g, ' ').trim();
          calls.push({ sql: normalizedSql, params });
          if (failOnCategory && /INSERT INTO app\.categories/.test(sql)) {
            throw new Error('Injected category insert failure.');
          }
          if (/SELECT id, status\s+FROM app\.users/.test(sql)) {
            return { rows: [] };
          }
          return { rows: [] };
        },
        release() {
          released = true;
        },
      };
    },
  };
}

test('creates partner defaults in one transaction and reuses the shared type profile', async () => {
  const pool = createPool();
  const result = await createPartnerWithDefaults({
    databasePool: pool,
    name: 'Example Bakery',
    type: 'bakery',
    ownerEmail: 'Owner@Example.test',
    ownerPhone: '+919876543210',
    shop: { name: 'Main Shop', address: { city: 'Mandapeta' } },
  });

  assert.equal(pool.calls[0].sql, 'BEGIN');
  assert.equal(pool.calls.at(-1).sql, 'COMMIT');
  assert.equal(pool.calls.filter(({ sql }) => /INSERT INTO app\.categories/.test(sql)).length, 4);
  assert.deepEqual(result.categories.map(({ name }) => name), [
    'Cakes',
    'Bread',
    'Pastries',
    'Cookies',
  ]);
  assert.deepEqual(result.user, {
    id: result.user.id,
    email: 'owner@example.test',
  });
  assert.match(
    pool.calls.find(({ sql }) => /INSERT INTO app\.users/.test(sql)).sql,
    /'Partner owner', 'customer', 'active'/,
  );
  assert.equal(pool.calls.some(({ sql }) => /password/i.test(sql)), false);
  assert.equal(pool.released, true);
});

test('rolls back all onboarding writes when a default category insert fails', async () => {
  const pool = createPool({ failOnCategory: true });

  await assert.rejects(
    createPartnerWithDefaults({
      databasePool: pool,
      name: 'Example Bakery',
      type: 'bakery',
      ownerEmail: 'owner@example.test',
      ownerPhone: '+919876543210',
      shop: { name: 'Main Shop' },
    }),
    /Injected category insert failure/,
  );

  assert.equal(pool.calls[0].sql, 'BEGIN');
  assert.equal(pool.calls.at(-1).sql, 'ROLLBACK');
  assert.equal(pool.calls.some(({ sql }) => sql === 'COMMIT'), false);
  assert.equal(pool.released, true);
});
