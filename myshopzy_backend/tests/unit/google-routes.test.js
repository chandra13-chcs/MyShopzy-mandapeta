const assert = require('node:assert/strict');
const test = require('node:test');

const {
  createGoogleRoutesClient,
  GoogleRoutesError,
} = require('../../src/modules/delivery-serviceability/google-routes');

const origin = { latitude: 16.87, longitude: 81.93 };
const destination = { latitude: 16.88, longitude: 81.94 };

function response(payload, { ok = true } = {}) {
  return {
    ok,
    async json() {
      return payload;
    },
  };
}

test('requests a driving route and only routes.distanceMeters', async () => {
  let request;
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async (...args) => {
      request = args;
      return response({ routes: [{ distanceMeters: 5000 }] });
    },
  });

  assert.equal(
    await client.getDrivingDistanceMeters({ origin, destination }),
    5000,
  );
  assert.equal(
    request[0],
    'https://routes.googleapis.com/directions/v2:computeRoutes',
  );
  assert.equal(request[1].method, 'POST');
  assert.equal(request[1].headers['X-Goog-Api-Key'], 'test-key');
  assert.equal(request[1].headers['X-Goog-FieldMask'], 'routes.distanceMeters');
  assert.deepEqual(JSON.parse(request[1].body), {
    origin: { location: { latLng: origin } },
    destination: { location: { latLng: destination } },
    travelMode: 'DRIVE',
  });
});

test('returns a valid route distance', async () => {
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => response({ routes: [{ distanceMeters: 1234 }] }),
  });

  assert.equal(
    await client.getDrivingDistanceMeters({ origin, destination }),
    1234,
  );
});

test('fails safely when the key is missing', async () => {
  const client = createGoogleRoutesClient({
    fetchImpl: async () => assert.fail('Must not call provider without a key.'),
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    { name: 'GoogleRoutesError', code: 'ROUTING_NOT_CONFIGURED' },
  );
});

test('times out and aborts a provider request that does not settle', async () => {
  let signal;
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    timeoutMs: 10,
    fetchImpl: (_url, options) => {
      signal = options.signal;
      return new Promise(() => {});
    },
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    { name: 'GoogleRoutesError', code: 'ROUTING_TIMEOUT' },
  );
  assert.equal(signal.aborted, true);
});

test('maps network errors without exposing underlying error text', async () => {
  const secretDetail = 'request failed with sensitive provider details';
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => {
      throw new Error(secretDetail);
    },
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    (error) => {
      assert.equal(error.code, 'ROUTING_NETWORK_ERROR');
      assert.equal(error.message.includes(secretDetail), false);
      return true;
    },
  );
});

test('maps unsuccessful provider responses without returning provider content', async () => {
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => ({
      ok: false,
      status: 403,
      async json() {
        return { error: { message: 'private provider detail' } };
      },
    }),
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    (error) => {
      assert.equal(error.code, 'ROUTING_PROVIDER_ERROR');
      assert.equal(error.message.includes('private provider detail'), false);
      return true;
    },
  );
});

test('reports no route when the provider returns an empty route list', async () => {
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => response({ routes: [] }),
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    { name: 'GoogleRoutesError', code: 'ROUTE_NOT_FOUND' },
  );
});

test('rejects malformed distance responses', async (t) => {
  for (const payload of [
    {},
    { routes: null },
    { routes: [{}] },
    { routes: [{ distanceMeters: '1000' }] },
    { routes: [{ distanceMeters: -1 }] },
    { routes: [{ distanceMeters: Number.MAX_SAFE_INTEGER + 1 }] },
  ]) {
    await t.test(JSON.stringify(payload), async () => {
      const client = createGoogleRoutesClient({
        apiKey: 'test-key',
        fetchImpl: async () => response(payload),
      });

      await assert.rejects(
        client.getDrivingDistanceMeters({ origin, destination }),
        { name: 'GoogleRoutesError', code: 'ROUTING_INVALID_RESPONSE' },
      );
    });
  }
});

test('rejects malformed JSON from the provider', async () => {
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => ({
      ok: true,
      async json() {
        throw new SyntaxError('provider response details');
      },
    }),
  });

  await assert.rejects(
    client.getDrivingDistanceMeters({ origin, destination }),
    { name: 'GoogleRoutesError', code: 'ROUTING_INVALID_RESPONSE' },
  );
});

test('validates origin and destination coordinates before requesting routes', async (t) => {
  const invalidCoordinates = [
    { latitude: Number.NaN, longitude: 0 },
    { latitude: Number.POSITIVE_INFINITY, longitude: 0 },
    { latitude: -90.01, longitude: 0 },
    { latitude: 90.01, longitude: 0 },
    { latitude: 0, longitude: Number.NaN },
    { latitude: 0, longitude: Number.NEGATIVE_INFINITY },
    { latitude: 0, longitude: -180.01 },
    { latitude: 0, longitude: 180.01 },
    { latitude: '16.87', longitude: 81.93 },
    null,
  ];

  for (const invalid of invalidCoordinates) {
    await t.test(JSON.stringify(invalid), async () => {
      let requested = false;
      const client = createGoogleRoutesClient({
        apiKey: 'test-key',
        fetchImpl: async () => {
          requested = true;
          return response({ routes: [{ distanceMeters: 1 }] });
        },
      });

      await assert.rejects(client.getDrivingDistanceMeters({
        origin: invalid,
        destination,
      }), TypeError);
      await assert.rejects(client.getDrivingDistanceMeters({
        origin,
        destination: invalid,
      }), TypeError);
      assert.equal(requested, false);
    });
  }

  const validEdgeCoordinates = {
    origin: { latitude: -90, longitude: -180 },
    destination: { latitude: 90, longitude: 180 },
  };
  const client = createGoogleRoutesClient({
    apiKey: 'test-key',
    fetchImpl: async () => response({ routes: [{ distanceMeters: 1 }] }),
  });
  assert.equal(
    await client.getDrivingDistanceMeters(validEdgeCoordinates),
    1,
  );
});

test('exposes only typed, sanitized routing errors', () => {
  const error = new GoogleRoutesError(
    'ROUTING_PROVIDER_ERROR',
    'Provider request failed.',
  );

  assert.equal(error.name, 'GoogleRoutesError');
  assert.equal(error.code, 'ROUTING_PROVIDER_ERROR');
  assert.equal(error.message, 'Provider request failed.');
});
