import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import createDefaultClient from '~/lib/graphql';

import TestCaseCreateApp from './components/test_case_create_root.vue';

Vue.use(VueApollo);

export function initTestCaseCreate({ mountPointSelector }) {
  const mountPointEl = document.querySelector(mountPointSelector);

  if (!mountPointEl) {
    return null;
  }

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el: mountPointEl,
    name: 'TestCaseCreateAppRoot',
    apolloProvider,
    provide: {
      ...mountPointEl.dataset,
    },
    component: TestCaseCreateApp,
  });
}
