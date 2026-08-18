// Tiny localStorage-backed TTL cache for Orbit API responses.
// Keeps each cached entry self-describing so a stale schema won't deserialize wrong.

import * as Sentry from '~/sentry/sentry_browser_wrapper';

const STORAGE_PREFIX = 'orbit-cache:';

export const FIVE_MINUTES_MS = 5 * 60 * 1000;

function storageKey(key) {
  return `${STORAGE_PREFIX}${key}`;
}

export function readCache(key) {
  try {
    const raw = localStorage.getItem(storageKey(key));
    if (!raw) return null;
    const entry = JSON.parse(raw);
    if (typeof entry?.expiresAt !== 'number' || entry.expiresAt < Date.now()) {
      localStorage.removeItem(storageKey(key));
      return null;
    }
    return entry.value;
  } catch (error) {
    Sentry.captureException(error);
    return null;
  }
}

export function writeCache(key, value, ttlMs = FIVE_MINUTES_MS) {
  try {
    const entry = { expiresAt: Date.now() + ttlMs, value };
    localStorage.setItem(storageKey(key), JSON.stringify(entry));
  } catch (error) {
    Sentry.captureException(error);
  }
}

export async function withCache(key, ttlMs, loader) {
  const cached = readCache(key);
  if (cached !== null) return cached;
  const value = await loader();
  writeCache(key, value, ttlMs);
  return value;
}
