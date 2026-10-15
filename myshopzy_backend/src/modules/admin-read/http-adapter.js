const { QueryValidationError } = require('./queries');

const REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/;
const POSTGRES_UNAVAILABLE_CODES = new Set([
  '08000',
  '08001',
  '08003',
  '08004',
  '08006',
  '08007',
  '57P01',
  '57P02',
  '57P03',
]);
const CONNECTION_FAILURE_CODES = new Set([
  'ECONNREFUSED',
  'ECONNRESET',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'ENETUNREACH',
  'EPIPE',
]);

function isDatabaseUnavailable(error) {
  return (error?.status === 503 && error?.code === 'DATABASE_UNAVAILABLE') ||
    POSTGRES_UNAVAILABLE_CODES.has(error?.code) ||
    CONNECTION_FAILURE_CODES.has(error?.code);
}

function requestMeta(requestId) {
  if (typeof requestId !== 'string' || !REQUEST_ID_PATTERN.test(requestId)) {
    throw new TypeError('A valid request ID is required to build an admin response.');
  }
  return { requestId };
}

function isPagination(pagination) {
  return pagination !== null &&
    typeof pagination === 'object' &&
    !Array.isArray(pagination) &&
    ['limit', 'offset', 'total'].every((key) =>
      Number.isSafeInteger(pagination[key]) && pagination[key] >= 0,
    );
}

function toListHttpResponse(result, requestId) {
  if (!result || !Array.isArray(result.data) || !isPagination(result.pagination)) {
    throw new TypeError('A valid admin list result is required.');
  }
  return {
    status: 200,
    body: {
      data: result.data,
      meta: {
        pagination: result.pagination,
        ...requestMeta(requestId),
      },
    },
  };
}

function toDetailHttpResponse(record, requestId) {
  if (record === null) {
    return {
      status: 404,
      body: {
        error: { code: 'NOT_FOUND', message: 'Resource not found.' },
        meta: requestMeta(requestId),
      },
    };
  }
  if (!record || typeof record !== 'object' || Array.isArray(record)) {
    throw new TypeError('A valid admin detail result is required.');
  }
  return {
    status: 200,
    body: {
      data: record,
      meta: requestMeta(requestId),
    },
  };
}

function toAuthenticationRequiredHttpResponse(requestId) {
  return {
    status: 401,
    body: {
      error: {
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Admin authentication is required.',
      },
      meta: requestMeta(requestId),
    },
  };
}

function toErrorHttpResponse(error, requestId) {
  let status = 500;
  let code = 'INTERNAL_SERVER_ERROR';
  let message = 'An unexpected error occurred.';

  if (error instanceof QueryValidationError) {
    status = 400;
    code = 'INVALID_REQUEST';
    message = error.message;
  } else if (isDatabaseUnavailable(error)) {
    status = 503;
    code = 'DATABASE_UNAVAILABLE';
    message = 'The service is temporarily unavailable.';
  }

  return {
    status,
    body: {
      error: { code, message },
      meta: requestMeta(requestId),
    },
  };
}

module.exports = {
  toAuthenticationRequiredHttpResponse,
  toDetailHttpResponse,
  toErrorHttpResponse,
  toListHttpResponse,
};
