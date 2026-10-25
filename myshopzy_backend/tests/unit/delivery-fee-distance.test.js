const assert = require('node:assert/strict');
const test = require('node:test');

const {
  DistanceUnavailableError,
  InvalidCoordinatesError,
  createDistanceClient,
  createFakeDistanceProvider,
  validateCoordinates,
} = require('../../src/modules/delivery-fee/distance');

const mandapeta = { latitude: 16.87, longitude: 81.93 };
const nearbyAddress = { latitude: 16.88, longitude: 81.94 };

test('uses an injectable fake road-distance provider', async () => {
  const client = createDistanceClient({
    provider: 'fake',
    fakeProvider: createFakeDistanceProvider({ distanceMetres: 5700 }),
  });

  assert.equal(
    await client.getRoadDistanceMetres(mandapeta, nearbyAddress),
    5700,
  );
});

test('converts provider failure to a typed distance-unavailable error', async () => {
  const client = createDistanceClient({
    provider: 'fake',
    fakeProvider: createFakeDistanceProvider({
      failure: new Error('private provider details'),
    }),
  });

  await assert.rejects(
    client.getRoadDistanceMetres(mandapeta, nearbyAddress),
    (error) =>
      error instanceof DistanceUnavailableError &&
      error.code === 'DISTANCE_UNAVAILABLE' &&
      error.status === 503 &&
      !error.message.includes('private provider details'),
  );
});

test('rejects coordinates outside the India bounding box', () => {
  assert.throws(
    () => validateCoordinates({ latitude: 40, longitude: 81 }),
    InvalidCoordinatesError,
  );
  assert.throws(
    () => validateCoordinates({ latitude: Number.NaN, longitude: 81 }),
    InvalidCoordinatesError,
  );
});
