const GOOGLE_ROUTES_URL =
  'https://routes.googleapis.com/directions/v2:computeRoutes';
const GOOGLE_ROUTES_FIELD_MASK = 'routes.distanceMeters';
const DEFAULT_TIMEOUT_MS = 8000;

class GoogleRoutesError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'GoogleRoutesError';
    this.code = code;
  }
}

function validateCoordinate(coordinate, label) {
  if (!coordinate || typeof coordinate !== 'object' || Array.isArray(coordinate)) {
    throw new TypeError(`${label} must contain valid latitude and longitude.`);
  }

  const { latitude, longitude } = coordinate;
  if (
    typeof latitude !== 'number' ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90
  ) {
    throw new TypeError(`${label} latitude must be between -90 and 90.`);
  }
  if (
    typeof longitude !== 'number' ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new TypeError(`${label} longitude must be between -180 and 180.`);
  }

  return { latitude, longitude };
}

function parseDistanceMeters(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new GoogleRoutesError(
      'ROUTING_INVALID_RESPONSE',
      'The routing provider returned an invalid response.',
    );
  }
  if (!Array.isArray(payload.routes)) {
    throw new GoogleRoutesError(
      'ROUTING_INVALID_RESPONSE',
      'The routing provider returned an invalid response.',
    );
  }
  if (payload.routes.length === 0) {
    throw new GoogleRoutesError(
      'ROUTE_NOT_FOUND',
      'No driving route is available for this destination.',
    );
  }

  const distanceMeters = payload.routes[0]?.distanceMeters;
  if (!Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
    throw new GoogleRoutesError(
      'ROUTING_INVALID_RESPONSE',
      'The routing provider returned an invalid distance.',
    );
  }
  return distanceMeters;
}

function createGoogleRoutesClient({
  apiKey = null,
  fetchImpl = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  if (typeof fetchImpl !== 'function') {
    throw new TypeError('A fetch implementation is required.');
  }
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0) {
    throw new TypeError('timeoutMs must be a positive safe integer.');
  }

  async function getDrivingDistanceMeters({ origin, destination }) {
    const validatedOrigin = validateCoordinate(origin, 'origin');
    const validatedDestination = validateCoordinate(
      destination,
      'destination',
    );
    const normalizedApiKey =
      typeof apiKey === 'string' ? apiKey.trim() : '';
    if (normalizedApiKey.length === 0) {
      throw new GoogleRoutesError(
        'ROUTING_NOT_CONFIGURED',
        'Delivery routing is not configured.',
      );
    }

    const controller = new AbortController();
    let timeoutId;
    let timedOut = false;
    const timeout = new Promise((resolve, reject) => {
      timeoutId = setTimeout(() => {
        timedOut = true;
        controller.abort();
        reject(
          new GoogleRoutesError(
            'ROUTING_TIMEOUT',
            'The routing provider did not respond in time.',
          ),
        );
      }, timeoutMs);
    });

    const request = (async () => {
      let response;
      try {
        response = await fetchImpl(GOOGLE_ROUTES_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': normalizedApiKey,
            'X-Goog-FieldMask': GOOGLE_ROUTES_FIELD_MASK,
          },
          body: JSON.stringify({
            origin: {
              location: { latLng: validatedOrigin },
            },
            destination: {
              location: { latLng: validatedDestination },
            },
            travelMode: 'DRIVE',
          }),
          signal: controller.signal,
        });
      } catch {
        if (timedOut || controller.signal.aborted) {
          throw new GoogleRoutesError(
            'ROUTING_TIMEOUT',
            'The routing provider did not respond in time.',
          );
        }
        throw new GoogleRoutesError(
          'ROUTING_NETWORK_ERROR',
          'The routing provider could not be reached.',
        );
      }

      if (!response?.ok) {
        throw new GoogleRoutesError(
          'ROUTING_PROVIDER_ERROR',
          'The routing provider could not calculate delivery distance.',
        );
      }

      let payload;
      try {
        payload = await response.json();
      } catch {
        throw new GoogleRoutesError(
          'ROUTING_INVALID_RESPONSE',
          'The routing provider returned an invalid response.',
        );
      }
      return parseDistanceMeters(payload);
    })();

    try {
      return await Promise.race([request, timeout]);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  return Object.freeze({ getDrivingDistanceMeters });
}

module.exports = {
  createGoogleRoutesClient,
  GoogleRoutesError,
  validateCoordinate,
};
