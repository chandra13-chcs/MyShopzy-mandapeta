'use strict';

const INDIA_BOUNDS = Object.freeze({
  minLatitude: 6.5,
  maxLatitude: 37.6,
  minLongitude: 68.1,
  maxLongitude: 97.4,
});
const ROUTING_TIMEOUT_MS = 3000;

class DistanceUnavailableError extends Error {
  constructor(message = 'Road distance is temporarily unavailable.') {
    super(message);
    this.name = 'DistanceUnavailableError';
    this.code = 'DISTANCE_UNAVAILABLE';
    this.status = 503;
  }
}

class InvalidCoordinatesError extends Error {
  constructor() {
    super('Coordinates must be finite and within India.');
    this.name = 'InvalidCoordinatesError';
    this.code = 'ADDRESS_LOCATION_INVALID';
    this.status = 422;
  }
}

function validateCoordinates(coordinates) {
  if (!coordinates || typeof coordinates !== 'object') {
    throw new InvalidCoordinatesError();
  }
  const { latitude, longitude } = coordinates;
  if (
    typeof latitude !== 'number' ||
    !Number.isFinite(latitude) ||
    latitude < INDIA_BOUNDS.minLatitude ||
    latitude > INDIA_BOUNDS.maxLatitude ||
    typeof longitude !== 'number' ||
    !Number.isFinite(longitude) ||
    longitude < INDIA_BOUNDS.minLongitude ||
    longitude > INDIA_BOUNDS.maxLongitude
  ) {
    throw new InvalidCoordinatesError();
  }
  return { latitude, longitude };
}

function createFakeDistanceProvider({ distanceMetres = 4000, failure = null } = {}) {
  return {
    async getRoadDistanceMetres(origin, destination) {
      if (failure) throw failure;
      if (!origin || !destination) throw new Error('Fake route coordinates are required.');
      return distanceMetres;
    },
  };
}

function createGoogleDistanceProvider({ apiKey, fetchImpl = globalThis.fetch }) {
  return {
    async getRoadDistanceMetres(origin, destination) {
      if (!apiKey || typeof fetchImpl !== 'function') {
        throw new DistanceUnavailableError();
      }

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), ROUTING_TIMEOUT_MS);
      try {
        const response = await fetchImpl(
          'https://routes.googleapis.com/directions/v2:computeRoutes',
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'routes.distanceMeters',
            },
            body: JSON.stringify({
              origin: {
                location: {
                  latLng: {
                    latitude: origin.latitude,
                    longitude: origin.longitude,
                  },
                },
              },
              destination: {
                location: {
                  latLng: {
                    latitude: destination.latitude,
                    longitude: destination.longitude,
                  },
                },
              },
              travelMode: 'DRIVE',
              routingPreference: 'TRAFFIC_UNAWARE',
            }),
            signal: controller.signal,
          },
        );
        if (!response.ok) throw new Error('Routing provider returned an error.');
        const body = await response.json();
        const distanceMetres = body?.routes?.[0]?.distanceMeters;
        if (!Number.isSafeInteger(distanceMetres) || distanceMetres < 0) {
          throw new Error('Routing provider returned an invalid distance.');
        }
        return distanceMetres;
      } catch {
        throw new DistanceUnavailableError();
      } finally {
        clearTimeout(timeout);
      }
    },
  };
}

function createDistanceClient({
  provider = process.env.ROUTING_PROVIDER || 'google',
  apiKey = process.env.ROUTING_API_KEY,
  fetchImpl = globalThis.fetch,
  fakeProvider = null,
} = {}) {
  let selectedProvider;
  if (provider === 'google') {
    selectedProvider = createGoogleDistanceProvider({ apiKey, fetchImpl });
  } else if (provider === 'fake') {
    selectedProvider = fakeProvider || createFakeDistanceProvider();
  } else {
    selectedProvider = {
      async getRoadDistanceMetres() {
        throw new DistanceUnavailableError();
      },
    };
  }

  return {
    async getRoadDistanceMetres(origin, destination) {
      const validOrigin = validateCoordinates(origin);
      const validDestination = validateCoordinates(destination);
      let timeout;
      try {
        const distanceMetres = await Promise.race([
          selectedProvider.getRoadDistanceMetres(validOrigin, validDestination),
          new Promise((resolve) => {
            timeout = setTimeout(
              () => resolve(null),
              ROUTING_TIMEOUT_MS,
            );
          }),
        ]);
        if (!Number.isSafeInteger(distanceMetres) || distanceMetres < 0) {
          throw new Error('Routing provider returned an invalid distance.');
        }
        return distanceMetres;
      } catch {
        throw new DistanceUnavailableError();
      } finally {
        clearTimeout(timeout);
      }
    },
  };
}

module.exports = {
  DistanceUnavailableError,
  INDIA_BOUNDS,
  InvalidCoordinatesError,
  ROUTING_TIMEOUT_MS,
  createDistanceClient,
  createFakeDistanceProvider,
  validateCoordinates,
};
