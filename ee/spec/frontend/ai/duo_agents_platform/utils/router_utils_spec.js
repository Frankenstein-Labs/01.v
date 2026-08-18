import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { safeRouterPush } from 'ee/ai/duo_agents_platform/utils/router_utils';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('safeRouterPush', () => {
  let mockRouter;

  beforeEach(() => {
    jest.clearAllMocks();
    mockRouter = { push: jest.fn() };
  });

  describe('successful navigation', () => {
    beforeEach(() => {
      mockRouter.push.mockResolvedValue();
    });

    it('calls router.push with the given location', async () => {
      const location = { name: 'test_route' };
      await safeRouterPush(mockRouter, location);

      expect(mockRouter.push).toHaveBeenCalledWith(location);
    });

    it('does not call Sentry.captureException', async () => {
      await safeRouterPush(mockRouter, { name: 'test_route' });

      expect(Sentry.captureException).not.toHaveBeenCalled();
    });
  });

  describe('NavigationDuplicated error', () => {
    beforeEach(() => {
      const error = new Error('Navigation duplicated');
      error.name = 'NavigationDuplicated';
      mockRouter.push.mockRejectedValue(error);
    });

    it('does not call Sentry.captureException', async () => {
      await safeRouterPush(mockRouter, { name: 'test_route' });

      expect(Sentry.captureException).not.toHaveBeenCalled();
    });

    it('does not throw', async () => {
      await expect(safeRouterPush(mockRouter, { name: 'test_route' })).resolves.toBeUndefined();
    });
  });

  describe('other navigation error', () => {
    const navigationError = new Error('Navigation aborted');

    beforeEach(() => {
      mockRouter.push.mockRejectedValue(navigationError);
    });

    it('calls Sentry.captureException with the error and tags', async () => {
      await expect(
        safeRouterPush(mockRouter, { name: 'target_route' }, { component: 'TestComponent' }),
      ).rejects.toThrow('Navigation aborted');

      expect(Sentry.captureException).toHaveBeenCalledWith(navigationError, {
        tags: {
          vue_component: 'TestComponent',
          navigation_target: 'target_route',
        },
      });
    });

    it('re-throws the error', async () => {
      await expect(safeRouterPush(mockRouter, { name: 'test_route' })).rejects.toThrow(
        'Navigation aborted',
      );
    });
  });

  describe('navigation target extraction', () => {
    const error = new Error('fail');

    beforeEach(() => {
      mockRouter.push.mockRejectedValue(error);
    });

    it('extracts name from named route location', async () => {
      await safeRouterPush(mockRouter, { name: 'my_route' }).catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        error,
        expect.objectContaining({
          tags: expect.objectContaining({ navigation_target: 'my_route' }),
        }),
      );
    });

    it('extracts path from path-based location', async () => {
      await safeRouterPush(mockRouter, { path: '/foo/bar' }).catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        error,
        expect.objectContaining({
          tags: expect.objectContaining({ navigation_target: '/foo/bar' }),
        }),
      );
    });

    it('uses string location directly', async () => {
      await safeRouterPush(mockRouter, '/some/path').catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        error,
        expect.objectContaining({
          tags: expect.objectContaining({ navigation_target: '/some/path' }),
        }),
      );
    });

    it('falls back to unknown for empty object', async () => {
      await safeRouterPush(mockRouter, {}).catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        error,
        expect.objectContaining({
          tags: expect.objectContaining({ navigation_target: 'unknown' }),
        }),
      );
    });
  });

  describe('component tag', () => {
    beforeEach(() => {
      mockRouter.push.mockRejectedValue(new Error('fail'));
    });

    it('passes component tag to Sentry when provided', async () => {
      await safeRouterPush(mockRouter, { name: 'r' }, { component: 'MyComp' }).catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        expect.any(Error),
        expect.objectContaining({ tags: expect.objectContaining({ vue_component: 'MyComp' }) }),
      );
    });

    it('omits component tag when not provided', async () => {
      await safeRouterPush(mockRouter, { name: 'r' }).catch(() => {});

      expect(Sentry.captureException).toHaveBeenCalledWith(
        expect.any(Error),
        expect.objectContaining({
          tags: expect.not.objectContaining({ vue_component: expect.anything() }),
        }),
      );
    });
  });
});
