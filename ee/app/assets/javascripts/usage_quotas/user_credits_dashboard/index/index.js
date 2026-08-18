import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createApolloClient from '~/lib/graphql';
import UserCreditsDashboardApp from './components/app.vue';
import { resolvers } from './graphql/resolvers';
import { userCreditsCacheConfig } from './apollo_cache_config';

/**
 * @param {HTMLElement} el
 */
export function initUserCreditsDashboard(el) {
  if (!el) return null;

  const { namespacePath } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({
    defaultClient: createApolloClient(resolvers, {
      cacheConfig: userCreditsCacheConfig,
    }),
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'UserCreditsDashboardRoot',
    provide: {
      namespacePath,
    },
    render(createElement) {
      return createElement(UserCreditsDashboardApp);
    },
  });
}
