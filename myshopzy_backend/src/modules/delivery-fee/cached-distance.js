'use strict';

const CACHE_TTL_MS = 3 * 60 * 1000;
const MAX_CACHE_ENTRIES = 500;

function createCachedDistanceClient(
  distanceClient,
  { ttlMs = CACHE_TTL_MS, maxEntries = MAX_CACHE_ENTRIES, now = Date.now } = {},
) {
  if (!distanceClient) return null;
  const cache = new Map();

  return Object.freeze({
    async getRoadDistanceMetres(origin, destination) {
      const key = [
        origin.latitude.toFixed(6),
        origin.longitude.toFixed(6),
        destination.latitude.toFixed(6),
        destination.longitude.toFixed(6),
      ].join(':');
      const cached = cache.get(key);
      if (cached && cached.expiresAt > now()) return cached.distanceMeters;
      if (cached) cache.delete(key);

      const distanceMeters = await distanceClient.getRoadDistanceMetres(
        origin,
        destination,
      );
      if (!Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
        return distanceMeters;
      }

      while (cache.size >= maxEntries) {
        cache.delete(cache.keys().next().value);
      }
      cache.set(key, {
        distanceMeters,
        expiresAt: now() + ttlMs,
      });
      return distanceMeters;
    },
  });
}

module.exports = {
  CACHE_TTL_MS,
  MAX_CACHE_ENTRIES,
  createCachedDistanceClient,
};
