import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createApolloClient from '~/lib/graphql';
import { usageBillingCacheConfig } from 'ee/usage_quotas/usage_billing/apollo_cache_config';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingUserDashboard(el) {
  if (!el) {
    return null;
  }

  // NOTE: namespacePath is only provided on SaaS for group usage billing dashboard page
  const { username, namespacePath } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({
    defaultClient: createApolloClient({}, { cacheConfig: usageBillingCacheConfig }),
  });

  return initVueApp({
    el,
    name: 'UsageBillingUserDashboardRoot',
    apolloProvider,
    provide: { username, namespacePath },
    component: UsageBillingUserDashboardApp,
  });
}
