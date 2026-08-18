import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import { parseBoolean } from '~/lib/utils/common_utils';
import SubscriptionApp from './components/app.vue';
import initialStore from './store';
import apolloProvider from './provider';

Vue.use(Vuex);

export default (containerId = 'js-billing-plans') => {
  const containerEl = document.getElementById(containerId);

  if (!containerEl) {
    return false;
  }

  const {
    namespaceId,
    namespaceName,
    addSeatsHref,
    planRenewHref,
    customerPortalUrl,
    billableSeatsHref,
    planName,
    refreshSeatsHref,
    readOnly,
    seatsLastUpdated,
  } = containerEl.dataset;

  return initVueApp({
    el: containerEl,
    name: 'SubscriptionAppRoot',
    store: new Vuex.Store(initialStore()),
    apolloProvider,
    provide: {
      namespaceId: Number(namespaceId),
      namespaceName,
      addSeatsHref,
      planRenewHref,
      customerPortalUrl,
      billableSeatsHref,
      planName,
      refreshSeatsHref,
      readOnly: parseBoolean(readOnly),
      seatsLastUpdated,
    },
    component: SubscriptionApp,
  });
};
