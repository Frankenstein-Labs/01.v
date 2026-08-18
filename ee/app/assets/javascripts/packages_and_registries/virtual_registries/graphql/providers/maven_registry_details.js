import { concatPagination } from '@apollo/client/utilities';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

export default new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          Group: {
            fields: {
              virtualRegistriesPackagesMavenUpstreams: {
                merge: true,
                keyArgs: ['groupPath', 'upstreamName'],
              },
            },
          },
          MavenUpstreamConnection: {
            fields: {
              nodes: concatPagination(),
            },
          },
        },
      },
    },
  ),
});
