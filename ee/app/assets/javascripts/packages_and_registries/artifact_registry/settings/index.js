import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { possibleTypes } from '../graphql/cache_config';
import { mockResolvers } from '../graphql/mock_resolvers';
import typeDefs from '../graphql/typedefs.graphql';
import App from './app.vue';

Vue.use(VueApollo);

export const initArtifactRegistrySettings = () => {
  const el = document.getElementById('js-artifact-registry-settings');

  if (!el) return false;

  const {
    dataset: { appData },
  } = el;
  const { organizationGid, clientBaseUrl } = convertObjectPropsToCamelCase(JSON.parse(appData));

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(mockResolvers, {
      cacheConfig: { possibleTypes },
      typeDefs,
    }),
  });

  return initVueApp({
    el,
    name: 'ArtifactRegistrySettingsRoot',
    apolloProvider,
    provide: {
      organizationGid,
      clientBaseUrl,
    },
    component: App,
  });
};
