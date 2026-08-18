import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import { createStore } from './store/edit';
import ProtectedEnvironmentsApp from './protected_environments_app.vue';

export const initProtectedEnvironments = () => {
  Vue.use(Vuex);

  const el = document.getElementById('js-protected-environments');

  if (!el) {
    return null;
  }

  // entityId is the ID of the project or group.
  // entityType is either 'projects' or 'groups'.
  const { entityId, apiLink, docsLink, entityType, tiers } = el.dataset;
  return initVueApp({
    el,
    name: 'ProtectedEnvironmentsAppRoot',
    store: createStore({
      ...el.dataset,
    }),
    provide: {
      entityId,
      entityType,
      tiers: tiers ? JSON.parse(tiers) : [],
      accessLevelsData: gon?.deploy_access_levels?.roles ?? [],
      apiLink,
      docsLink,
      searchUnprotectedEnvironmentsUrl: gon.search_unprotected_environments_url,
    },
    component: ProtectedEnvironmentsApp,
  });
};
