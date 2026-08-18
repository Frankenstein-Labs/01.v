import { logError } from '~/lib/logger';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { evictCache, fetchCount } from '../graphql/utils';
import { UPDATE_TOTAL_ITEMS } from './mutation_types';

/** @type {import('vuex').Action<any, any>} */
export const invalidatePromotionRequestsData = async (
  { commit, state },
  { context, group, project },
) => {
  if (!state.enabled) {
    return;
  }

  // Evict cache for PromotionRequestsTabApp (../components/app.vue) component GraphQL data. So that
  // when the tab is re-opened — instead of displaying the stale cache data, the list would be
  // refetched.
  evictCache({ context, group, project });

  // Update the counter on the promotion requests tab
  try {
    const count = await fetchCount({ context, group, project });
    commit(UPDATE_TOTAL_ITEMS, count);
  } catch (error) {
    logError(s__('PromotionRequests|Error fetching promotion requests count'), error);
    Sentry.captureException(error);
  }
};
