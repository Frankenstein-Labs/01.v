import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import DevopsAdoptionApp from './components/devops_adoption_app.vue';
import { createApolloProvider } from './graphql';

export default () => {
  const el = document.querySelector('.js-devops-adoption');

  if (!el) return false;

  const { groupId, devopsScoreMetrics } = el.dataset;

  const isGroup = Boolean(groupId);

  return initVueApp({
    el,
    name: 'DevopsAdoptionAppRoot',
    apolloProvider: createApolloProvider(groupId),
    provide: {
      isGroup,
      groupGid: isGroup ? convertToGraphQLId(TYPENAME_GROUP, groupId) : null,
      devopsScoreMetrics: isGroup ? null : JSON.parse(devopsScoreMetrics),
    },
    component: DevopsAdoptionApp,
  });
};
