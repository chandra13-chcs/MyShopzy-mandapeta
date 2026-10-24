const assert = require('node:assert/strict');
const test = require('node:test');
const {
  toDetailHttpResponse,
  toErrorHttpResponse,
  toListHttpResponse,
} = require('../../src/modules/admin-read/http-adapter');
const {
  getResource,
  listResource,
} = require('../../src/modules/admin-read/queries');

const requestId = 'integration-test-123';
const productId = 'e6c203e8-8254-47db-883c-0b8fb688b14b';

function createFakePool(responses) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      const response = responses[calls.length - 1];
      if (response instanceof Error) throw response;
      return response ?? { rows: [] };
    },
  };
}

async function listHttpResponse(pool, resource, query, id = requestId) {
  try {
    return toListHttpResponse(await listResource(pool, resource, query), id);
  } catch (error) {
    return toErrorHttpResponse(error, id);
  }
}

async function detailHttpResponse(pool, resource, recordId, id = requestId) {
  try {
    return toDetailHttpResponse(await getResource(pool, resource, recordId), id);
  } catch (error) {
    return toErrorHttpResponse(error, id);
  }
}

test('maps an in-memory query list result to the HTTP success envelope', async () => {
  const pool = createFakePool([
    { rows: [{ total: '1' }] },
    { rows: [{ id: productId, name: 'Tea' }] },
  ]);

  const response = await listHttpResponse(pool, 'products', { limit: '5', offset: '2' });

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, {
    data: [{ id: productId, name: 'Tea' }],
    meta: {
      pagination: { limit: 5, offset: 2, total: 1 },
      requestId,
    },
  });
  assert.equal(pool.calls.length, 2);
});

test('maps an in-memory detail record and missing detail to success and not-found envelopes', async () => {
  const recordPool = createFakePool([{ rows: [{ id: productId, name: 'Tea' }] }]);
  const recordResponse = await detailHttpResponse(recordPool, 'products', productId);

  assert.deepEqual(recordResponse, {
    status: 200,
    body: { data: { id: productId, name: 'Tea' }, meta: { requestId } },
  });

  const missingPool = createFakePool([{ rows: [] }]);
  const missingResponse = await detailHttpResponse(missingPool, 'products', productId);
  assert.deepEqual(missingResponse, {
    status: 404,
    body: {
      error: { code: 'NOT_FOUND', message: 'Resource not found.' },
      meta: { requestId },
    },
  });
});

test('does not return arbitrary or nested order snapshot JSON in detail responses', async () => {
  const sensitiveSnapshot = {
    customer: { email: 'private@example.test' },
    delivery: { instruction: 'leave at the rear entrance' },
    internal: ['secret'],
  };
  const pool = createFakePool([
    { rows: [{ id: productId, totalMinor: '1000' }] },
    {
      rows: [{
        productId,
        productName: 'Tea',
        sku: 'TEA-1',
        unitPriceMinor: '1000',
        quantity: 1,
        lineTotalMinor: '1000',
        commissionBps: 1000,
        commissionMinor: '100',
        currency: 'USD',
        variantSnapshot: sensitiveSnapshot,
      }],
    },
  ]);

  const response = await detailHttpResponse(pool, 'orders', productId);

  assert.equal(response.status, 200);
  assert.deepEqual(response.body.data.items, [{
    productId,
    productName: 'Tea',
    sku: 'TEA-1',
    unitPriceMinor: '1000',
    quantity: 1,
    lineTotalMinor: '1000',
    commissionBps: 1000,
    commissionMinor: '100',
    currency: 'USD',
  }]);
  assert.doesNotMatch(pool.calls[1].sql, /variant_snapshot|variantSnapshot/);
  assert.doesNotMatch(JSON.stringify(response), /private@example\.test|rear entrance|secret|variantSnapshot/);
});

test('maps invalid filters and calendar dates to 400 before querying the fake pool', async () => {
  for (const query of [
    { listingStatus: 'pending' },
    { createdFrom: '2026-02-31T00:00:00Z' },
  ]) {
    const pool = createFakePool([]);
    const response = await listHttpResponse(pool, 'products', query);

    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, 'INVALID_REQUEST');
    assert.equal(response.body.meta.requestId, requestId);
    assert.equal(pool.calls.length, 0);
  }
});

test('maps explicitly classified database unavailability to sanitized 503', async () => {
  const unavailable = new Error('private database credentials and connection diagnostic');
  unavailable.status = 503;
  unavailable.code = 'DATABASE_UNAVAILABLE';
  const pool = createFakePool([unavailable]);

  const response = await listHttpResponse(pool, 'products', {});

  assert.equal(response.status, 503);
  assert.deepEqual(response.body, {
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'The service is temporarily unavailable.',
    },
    meta: { requestId },
  });
  assert.doesNotMatch(JSON.stringify(response), /private|credentials|connection/);
});

test('classifies recognized driver connection errors but not SQL or unknown failures', async () => {
  for (const code of ['08006', '57P03', 'ECONNREFUSED', 'ETIMEDOUT']) {
    const failure = Object.assign(
      new Error(`private connection string and driver detail ${code}`),
      { code },
    );
    const pool = createFakePool([failure]);
    const response = await listHttpResponse(pool, 'products', {});

    assert.equal(response.status, 503);
    assert.equal(response.body.error.code, 'DATABASE_UNAVAILABLE');
    assert.equal(response.body.meta.requestId, requestId);
    assert.doesNotMatch(JSON.stringify(response), /private|connection string|driver detail|08006|57P03|ECONN|ETIMEDOUT/);
  }

  for (const code of ['42601', '23505', '08P01', 'UNRECOGNIZED']) {
    const failure = Object.assign(
      new Error(`private SQL and database diagnostic ${code}`),
      { code },
    );
    const pool = createFakePool([failure]);
    const response = await listHttpResponse(pool, 'products', {});

    assert.equal(response.status, 500);
    assert.equal(response.body.error.code, 'INTERNAL_SERVER_ERROR');
    assert.equal(response.body.meta.requestId, requestId);
    assert.doesNotMatch(JSON.stringify(response), /private|diagnostic|42601|23505|08P01|UNRECOGNIZED/);
  }
});

test('maps unexpected database failures to sanitized 500', async () => {
  const failure = new Error('SELECT * FROM app.users; password=secret');
  failure.stack = 'internal stack trace with credential=secret';
  const pool = createFakePool([failure]);

  const response = await listHttpResponse(pool, 'products', {});
  assert.equal(response.status, 500);
  assert.deepEqual(response.body, {
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred.',
    },
    meta: { requestId },
  });
  assert.doesNotMatch(
    JSON.stringify(response),
    /SELECT|app\.users|password|secret|stack|credential|internal/,
  );
});

test('rejects invalid request IDs and keeps valid IDs in meta for success and errors', async () => {
  const pool = createFakePool([{ rows: [{ total: '0' }] }, { rows: [] }]);

  const success = await listHttpResponse(pool, 'products', {});
  assert.equal(success.body.meta.requestId, requestId);

  await assert.rejects(
    listHttpResponse(pool, 'products', {}, 'untrusted\nid'),
    (error) => {
      assert.equal(error.message, 'A valid request ID is required to build an admin response.');
      assert.doesNotMatch(error.message, /untrusted/);
      return true;
    },
  );

  const validationError = await listHttpResponse(pool, 'products', { listingStatus: 'pending' });
  assert.equal(validationError.body.meta.requestId, requestId);
});

test('keeps Product aliases parameterized and never interpolates supplied values into SQL', async () => {
  const search = "tea' OR 1=1 --";
  const createdFrom = '2026-10-01T00:00:00Z';
  const createdTo = '2026-11-01T00:00:00Z';
  const pool = createFakePool([
    { rows: [{ total: '1' }] },
    { rows: [{ id: productId, listingStatus: 'archived' }] },
  ]);

  const response = await listHttpResponse(pool, 'products', {
    q: search,
    listingStatus: 'archived',
    createdFrom,
    createdTo,
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.data[0].listingStatus, 'archived');
  assert.match(pool.calls[0].sql, /pr\.status = \$2/);
  assert.match(pool.calls[0].sql, /pr\.created_at >= \$3/);
  assert.match(pool.calls[0].sql, /pr\.created_at < \$4/);
  assert.deepEqual(pool.calls[0].params, [search, 'archived', createdFrom, createdTo]);
  for (const { sql, params } of pool.calls) {
    assert.ok(params.includes(search));
    assert.doesNotMatch(sql, /tea' OR 1=1/);
    assert.doesNotMatch(sql, /2026-10-01T00:00:00Z|2026-11-01T00:00:00Z|archived/);
  }
});
