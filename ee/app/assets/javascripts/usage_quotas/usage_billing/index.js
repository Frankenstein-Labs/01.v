import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createApolloClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import UsageBillingDashboardPage from 'ee/usage_quotas/usage_billing/components/meta_app.vue';
import { usageBillingCacheConfig } from './apollo_cache_config';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingDashboard(el) {
  if (!el) {
    return null;
  }

  const {
    userUsagePath,
    isSaas,
    isFree,
    isPaidBasePlan,
    namespacePath,
    upgradeButtonPath,
    purchaseCreditsPath,
    creditsGeneralizationUi,
  } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({
    defaultClient: createApolloClient({}, { cacheConfig: usageBillingCacheConfig }),
  });

  return initVueApp({
    el,
    name: 'UsageBillingDashboardRoot',
    apolloProvider,
    provide: {
      userUsagePath,
      isSaas: parseBoolean(isSaas),
      isFree: parseBoolean(isFree),
      isPaidBasePlan: parseBoolean(isPaidBasePlan),
      namespacePath,
      upgradeButtonPath,
      purchaseCreditsPath,
      creditsGeneralizationUi: parseBoolean(creditsGeneralizationUi),
    },
    component: UsageBillingDashboardPage,
  });
}
