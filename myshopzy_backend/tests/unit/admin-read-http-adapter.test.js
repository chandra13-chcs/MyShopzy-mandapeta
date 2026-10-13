const assert = require('node:assert/strict');
const test = require('node:test');
const {
  toDetailHttpResponse,
  toErrorHttpResponse,
  toListHttpResponse,
} = require('../../src/modules/admin-read/http-adapter');
const { QueryValidationError } = require('../../src/modules/admin-read/queries');

const requestId = 'request-123';

test('accepts request IDs matching the documented format and maximum length', () => {
  const maximumLengthId = `a${'b'.repeat(63)}`;
  const validIds = ['request-123', 'trace.id:part_2', maximumLengthId];

  for (const validId of validIds) {
    assert.equal(
      toDetailHttpResponse({ id: 'record-1' }, validId).body.meta.requestId,
      validId,
    );
  }
});

test('rejects missing, malformed, whitespace, control-character, and oversized request IDs', () => {
  const invalidIds = [
    undefined,
    null,
    123,
    '',
    '   ',
    ' request-123',
    'request-123 ',
    'request id',
    'request\nid',
    'request/id',
    `a${'b'.repeat(64)}`,
  ];

  for (const invalidId of invalidIds) {
    assert.throws(
      () => toErrorHttpResponse(new Error('private diagnostic'), invalidId),
      (error) => {
        assert.equal(
          error.message,
          'A valid request ID is required to build an admin response.',
        );
        return true;
      },
    );
  }
});

test('wraps list query results with pagination and request ID', () => {
  const result = toListHttpResponse({
    data: [],
    pagination: { limit: 25, offset: 0, total: 0 },
  }, requestId);

  assert.deepEqual(result, {
    status: 200,
    body: {
      data: [],
      meta: {
        pagination: { limit: 25, offset: 0, total: 0 },
        requestId,
      },
    },
  });
});

test('rejects malformed list pagination without exposing input details', () => {
  const malformedPagination = [
    undefined,
    {},
    { limit: 1, offset: 0 },
    { limit: '25', offset: 0, total: 0 },
    { limit: 25, offset: '0', total: 0 },
    { limit: 25, offset: 0, total: null },
    { limit: -1, offset: 0, total: 0 },
    { limit: 25, offset: -1, total: 0 },
    { limit: 25, offset: 0, total: -1 },
    { limit: 25.5, offset: 0, total: 0 },
    { limit: Number.MAX_SAFE_INTEGER + 1, offset: 0, total: 0 },
    null,
    [],
  ];

  for (const pagination of malformedPagination) {
    assert.throws(
      () => toListHttpResponse({ data: [], pagination }, requestId),
      (error) => {
        assert.equal(error.message, 'A valid admin list result is required.');
        assert.equal(error.message.includes(JSON.stringify(pagination)), false);
        return true;
      },
    );
  }
});

test('accepts non-negative safe integer pagination boundaries', () => {
  const pagination = {
    limit: 0,
    offset: Number.MAX_SAFE_INTEGER,
    total: Number.MAX_SAFE_INTEGER,
  };
  assert.deepEqual(
    toListHttpResponse({ data: [], pagination }, requestId).body.meta.pagination,
    pagination,
  );
});

test('wraps detail records with request ID', () => {
  const record = { id: 'record-1', name: 'Record' };
  assert.deepEqual(toDetailHttpResponse(record, requestId), {
    status: 200,
    body: {
      data: record,
      meta: { requestId },
    },
  });
});

test('maps null detail results to a not-found envelope', () => {
  assert.deepEqual(toDetailHttpResponse(null, requestId), {
    status: 404,
    body: {
      error: { code: 'NOT_FOUND', message: 'Resource not found.' },
      meta: { requestId },
    },
  });
});

test('maps typed query validation errors to a 400 envelope', () => {
  assert.deepEqual(toErrorHttpResponse(
    new QueryValidationError('limit must be a decimal integer.'),
    requestId,
  ), {
    status: 400,
    body: {
      error: {
        code: 'INVALID_REQUEST',
        message: 'limit must be a decimal integer.',
      },
      meta: { requestId },
    },
  });
});

test('maps known database unavailability to a generic 503 envelope', () => {
  const error = new Error('Database is unavailable.');
  error.status = 503;
  error.code = 'DATABASE_UNAVAILABLE';

  assert.deepEqual(toErrorHttpResponse(error, requestId), {
    status: 503,
    body: {
      error: {
        code: 'DATABASE_UNAVAILABLE',
        message: 'The service is temporarily unavailable.',
      },
      meta: { requestId },
    },
  });
});

test('maps recognized PostgreSQL connection and availability SQLSTATEs to sanitized 503', () => {
  const unavailableCodes = [
    '08000',
    '08001',
    '08003',
    '08004',
    '08006',
    '08007',
    '57P01',
    '57P02',
    '57P03',
  ];

  for (const code of unavailableCodes) {
    const response = toErrorHttpResponse(
      Object.assign(new Error(`private driver detail for ${code}`), { code }),
      requestId,
    );

    assert.equal(response.status, 503);
    assert.deepEqual(response.body, {
      error: {
        code: 'DATABASE_UNAVAILABLE',
        message: 'The service is temporarily unavailable.',
      },
      meta: { requestId },
    });
    assert.doesNotMatch(JSON.stringify(response), /private|driver detail|08000|57P/);
  }
});

test('maps recognized Node.js connection failures to sanitized 503', () => {
  for (const code of [
    'ECONNREFUSED',
    'ECONNRESET',
    'ETIMEDOUT',
    'EHOSTUNREACH',
    'ENETUNREACH',
    'EPIPE',
  ]) {
    const response = toErrorHttpResponse(
      Object.assign(new Error(`private socket detail for ${code}`), { code }),
      requestId,
    );

    assert.equal(response.status, 503);
    assert.equal(response.body.error.code, 'DATABASE_UNAVAILABLE');
    assert.equal(response.body.meta.requestId, requestId);
    assert.doesNotMatch(JSON.stringify(response), /private|socket detail|ECONN|ETIMEDOUT/);
  }
});

test('does not classify SQL syntax, constraint, or unknown errors as database unavailable', () => {
  for (const code of ['42601', '23505', '08P01', '53300', 'UNKNOWN_DRIVER_CODE']) {
    const response = toErrorHttpResponse(
      Object.assign(new Error(`private database diagnostic for ${code}`), { code }),
      requestId,
    );

    assert.equal(response.status, 500);
    assert.deepEqual(response.body, {
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred.',
      },
      meta: { requestId },
    });
    assert.doesNotMatch(JSON.stringify(response), /private|diagnostic|42601|23505|UNKNOWN/);
  }
});

test('sanitizes unexpected errors and requires an explicitly supplied request ID', () => {
  const error = new Error('private database diagnostic with SQL');
  error.stack = 'private stack trace';
  const response = toErrorHttpResponse(error, requestId);

  assert.deepEqual(response, {
    status: 500,
    body: {
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred.',
      },
      meta: { requestId },
    },
  });
  assert.equal(JSON.stringify(response).includes('private'), false);
  assert.throws(() => toErrorHttpResponse(error), /valid request ID/);
});

test('sanitizes unknown errors of every supported JavaScript value shape', () => {
  const unknownErrors = [
    Object.assign(new Error('SQL password=secret database diagnostic'), {
      stack: 'stack with credential=secret',
    }),
    {
      message: 'SQL password=secret database diagnostic',
      stack: 'stack with credential=secret',
      code: 'CONFLICT',
      status: 409,
    },
    'SQL password=secret database diagnostic',
    null,
  ];

  for (const error of unknownErrors) {
    const response = toErrorHttpResponse(error, requestId);
    assert.equal(response.status, 500);
    assert.deepEqual(response.body, {
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred.',
      },
      meta: { requestId },
    });
    assert.doesNotMatch(JSON.stringify(response), /SQL|password|secret|database|stack|CONFLICT/);
  }
});
