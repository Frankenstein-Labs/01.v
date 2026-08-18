import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

const defaultClient = createDefaultClient(
  {},
  {
    cacheConfig: {
      typePolicies: {
        GoogleCloudArtifactRegistryRepository: {
          keyFields: ['projectId'],
        },
      },
    },
  },
);

export const apolloProvider = new VueApollo({
  defaultClient,
});
