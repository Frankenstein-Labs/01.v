import * as Sentry from '~/sentry/sentry_browser_wrapper';

const isNavigationDuplicated = (error) => error?.name === 'NavigationDuplicated';

const getNavigationTarget = (location) => {
  if (typeof location === 'string') return location;
  return location?.name || location?.path || 'unknown';
};

/**
 * Wraps router.push to report navigation errors to Sentry.
 * Silently ignores NavigationDuplicated errors.
 * Reports all other errors to Sentry, then re-throws so callers
 * can still handle them (e.g., fallback navigation).
 */
export const safeRouterPush = async (router, location, { component } = {}) => {
  try {
    return await router.push(location);
  } catch (error) {
    if (isNavigationDuplicated(error)) return undefined;

    const tags = { navigation_target: getNavigationTarget(location) };
    if (component) {
      tags.vue_component = component;
    }

    Sentry.captureException(error, { tags });
    throw error;
  }
};
