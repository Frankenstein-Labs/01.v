import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { parseBoolean } from '~/lib/utils/common_utils';
import AiCatalogBreadcrumbs from './router/ai_catalog_breadcrumbs.vue';

import AiCatalogApp from './ai_catalog_app.vue';
import { NAMESPACE_EXPLORE } from './constants';
import { createRouter } from './router';

export const initAiCatalog = (selector = '#js-ai-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const {
    aiCatalogIndexPath,
    aiImpactDashboardEnabled,
    showLegalDisclaimer,
    instanceBetaFeaturesEnabled,
    timezoneData,
    userTimezone,
  } = dataset;

  Vue.use(VueApollo);
  Vue.use(GlToast);

  const router = createRouter(aiCatalogIndexPath);

  // Merge paginated Query.projects pages in the cache so SingleSelectDropdown
  // can drop the deprecated `updateQuery` callback. Replace on first-page
  // fetches; appending would duplicate refs under `cache-and-network`.
  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(
      {},
      {
        cacheConfig: {
          typePolicies: {
            Query: {
              fields: {
                projects: {
                  keyArgs: ['search', 'membership', 'minAccessLevel', 'searchNamespaces', 'sort'],
                  merge(existing, incoming, { args }) {
                    if (!args?.after) return incoming;
                    return {
                      ...incoming,
                      nodes: [...(existing?.nodes ?? []), ...(incoming.nodes ?? [])],
                    };
                  },
                },
              },
            },
          },
        },
      },
    ),
  });

  injectVueAppBreadcrumbs(router, AiCatalogBreadcrumbs);

  return initVueApp({
    el,
    name: 'AiCatalogRoot',
    router,
    apolloProvider,
    provide: {
      namespace: NAMESPACE_EXPLORE,
      isGlobalNamespace: true,
      isProjectNamespace: false,
      isGroupNamespace: false,
      aiImpactDashboardEnabled: parseBoolean(aiImpactDashboardEnabled),
      instanceBetaFeaturesEnabled: parseBoolean(instanceBetaFeaturesEnabled),
      showLegalDisclaimer: parseBoolean(showLegalDisclaimer),
      timezoneData: timezoneData ? JSON.parse(timezoneData) : [],
      userTimezone: userTimezone || '',
    },
    component: AiCatalogApp,
  });
};
