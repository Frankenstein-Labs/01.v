import { readCache, writeCache, withCache, FIVE_MINUTES_MS } from 'ee/orbit/utils/orbit_cache';

describe('orbit_cache', () => {
  beforeEach(() => {
    localStorage.clear();
    jest.spyOn(Date, 'now').mockReturnValue(1_000_000);
  });

  afterEach(() => {
    Date.now.mockRestore();
  });

  describe('writeCache + readCache', () => {
    it('returns null when the key was never written', () => {
      expect(readCache('missing')).toBeNull();
    });

    it('returns the value back within the TTL window', () => {
      writeCache('foo', { hello: 'world' });
      expect(readCache('foo')).toEqual({ hello: 'world' });
    });

    it('returns null and evicts the entry once expired', () => {
      writeCache('foo', { hello: 'world' }, 1000);
      Date.now.mockReturnValue(1_001_500);

      expect(readCache('foo')).toBeNull();
      expect(localStorage.getItem('orbit-cache:foo')).toBeNull();
    });
  });

  describe('withCache', () => {
    it('runs the loader on a miss and caches the result', async () => {
      const loader = jest.fn().mockResolvedValue({ data: 1 });

      const value = await withCache('key', FIVE_MINUTES_MS, loader);

      expect(value).toEqual({ data: 1 });
      expect(loader).toHaveBeenCalledTimes(1);
      expect(readCache('key')).toEqual({ data: 1 });
    });

    it('skips the loader on a cache hit', async () => {
      writeCache('key', { hit: true });
      const loader = jest.fn();

      const value = await withCache('key', FIVE_MINUTES_MS, loader);

      expect(value).toEqual({ hit: true });
      expect(loader).not.toHaveBeenCalled();
    });
  });
});
