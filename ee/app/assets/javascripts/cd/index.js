import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { initSinglePageApplication } from '~/vue_shared/spa';
import { createRouter } from './router';

const cdTypePolicies = {
  CdApplication: {
    fields: {
      environments: { merge: true },
    },
  },
  CdVersionSet: {
    fields: {
      versionSetEntries: { merge: true },
    },
  },
};

export const initCdRoot = () => {
  const el = document.querySelector('.js-cd-root');
  if (!el) {
    return null;
  }

  const { baseRoute } = el.dataset;
  const router = createRouter(baseRoute);

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient({}, { cacheConfig: { typePolicies: cdTypePolicies } }),
  });

  return initSinglePageApplication({
    name: 'CdRoot',
    el,
    router,
    // Skip auto Apollo creation — we provide our own above.
    apolloCacheConfig: null,
    options: { apolloProvider },
  });
};
