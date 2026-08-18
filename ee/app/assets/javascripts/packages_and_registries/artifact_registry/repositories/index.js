import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { observable } from '~/lib/utils/observable';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { possibleTypes, typePolicies } from '../graphql/cache_config';
import { mockResolvers } from '../graphql/mock_resolvers';
import typeDefs from '../graphql/typedefs.graphql';
import { createRouter } from '../router';
import App from './app.vue';
import ArtifactRegistryBreadcrumbs from './artifact_registry_breadcrumbs.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initArtifactRegistryRepositories = () => {
  const el = document.getElementById('js-artifact-registry-repositories');

  if (!el) return false;

  const {
    dataset: { appData },
  } = el;
  const { organizationGid, slug, basePath, clientBaseUrl } = convertObjectPropsToCamelCase(
    JSON.parse(appData),
  );

  // `typePolicies` holds real cache policies; `mockResolvers`, `typeDefs`, and
  // `possibleTypes` back the Artifact Registry entities the GraphQL schema does not carry
  // yet. Removing the mock means dropping the first argument, `typeDefs`, and
  // `possibleTypes`, and keeping `typePolicies`.
  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(mockResolvers, {
      cacheConfig: { typePolicies, possibleTypes },
      typeDefs,
    }),
  });

  // The version list route is addressed by an opaque artifact id, so the page publishes
  // the name it resolves and the trail and the title render that instead.
  const breadCrumbState = observable('artifact_registry_breadcrumb', {
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

  const router = createRouter(basePath, breadCrumbState);

  injectVueAppBreadcrumbs(router, ArtifactRegistryBreadcrumbs, apolloProvider);

  return initVueApp({
    el,
    name: 'ArtifactRegistryRepositoriesRoot',
    router,
    apolloProvider,
    provide: {
      breadCrumbState,
      organizationGid,
      slug,
      clientBaseUrl,
    },
    component: App,
  });
};
