import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import PendingMembersApp from './components/app.vue';
import apolloProvider from './graphql_client';

Vue.use(VueApollo);

export default (containerId = 'js-pending-members-app') => {
  const el = document.getElementById(containerId);

  if (!el) {
    return false;
  }

  const { namespaceId, namespacePath, userCapSet } = el.dataset;

  return initVueApp({
    el,
    name: 'PendingMembersAppRoot',
    apolloProvider,
    provide: {
      namespacePath,
      namespaceId,
      userCapSet: parseBoolean(userCapSet),
    },
    component: PendingMembersApp,
  });
};
