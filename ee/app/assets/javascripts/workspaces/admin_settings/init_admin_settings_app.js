import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_ORGANIZATION } from '~/graphql_shared/constants';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import WorkspacesAgentAvailabilityApp from './pages/app.vue';

Vue.use(VueApollo);

const createApolloProvider = () => {
  const defaultClient = createDefaultClient();

  return new VueApollo({ defaultClient });
};

const initWorkspacesAgentAvailabilityApp = () => {
  const el = document.getElementById('js-workspaces-agent-availability-settings');

  if (!el?.dataset) return null;

  const { organizationId, defaultExpanded } = el.dataset;

  return initVueApp({
    el,
    name: 'WorkspacesAgentAvailabilityAppRoot',
    apolloProvider: createApolloProvider(),
    component: WorkspacesAgentAvailabilityApp,
    provide: {
      organizationId: convertToGraphQLId(TYPE_ORGANIZATION, organizationId),
      defaultExpanded: parseBoolean(defaultExpanded),
    },
  });
};

export { initWorkspacesAgentAvailabilityApp };
