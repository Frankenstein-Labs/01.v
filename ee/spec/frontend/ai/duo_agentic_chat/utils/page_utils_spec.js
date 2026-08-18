import { getPagePath } from 'ee/ai/duo_agentic_chat/utils/page_utils';

describe('page_utils', () => {
  describe('getPagePath', () => {
    it('returns pathname from window.location', () => {
      const path = getPagePath();

      expect(typeof path).toBe('string');
      expect(path.startsWith('/')).toBe(true);
    });

    it('returns empty string when window does not exist', () => {
      const originalWindow = global.window;
      delete global.window;

      const path = getPagePath();

      expect(path).toBe('');

      global.window = originalWindow;
    });

    it('returns empty string when window.location does not exist', () => {
      const originalLocation = window.location;
      Object.defineProperty(window, 'location', {
        value: undefined,
        configurable: true,
      });

      const path = getPagePath();

      expect(path).toBe('');

      Object.defineProperty(window, 'location', {
        value: originalLocation,
        configurable: true,
      });
    });

    it('extracts pathname without query parameters and hash', () => {
      const originalLocation = window.location;
      const mockLocation = { pathname: '/test/path' };
      Object.defineProperty(window, 'location', {
        value: mockLocation,
        configurable: true,
      });

      const path = getPagePath();

      expect(path).toBe('/test/path');

      Object.defineProperty(window, 'location', {
        value: originalLocation,
        configurable: true,
      });
    });

    it('handles root pathname', () => {
      const originalLocation = window.location;
      const mockLocation = { pathname: '/' };
      Object.defineProperty(window, 'location', {
        value: mockLocation,
        configurable: true,
      });

      const path = getPagePath();

      expect(path).toBe('/');

      Object.defineProperty(window, 'location', {
        value: originalLocation,
        configurable: true,
      });
    });

    it('handles complex paths with multiple segments', () => {
      const originalLocation = window.location;
      const mockLocation = { pathname: '/group/project/issues/123' };
      Object.defineProperty(window, 'location', {
        value: mockLocation,
        configurable: true,
      });

      const path = getPagePath();

      expect(path).toBe('/group/project/issues/123');

      Object.defineProperty(window, 'location', {
        value: originalLocation,
        configurable: true,
      });
    });
  });
});
