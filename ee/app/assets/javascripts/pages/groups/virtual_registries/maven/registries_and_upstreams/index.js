import apolloProvider from 'ee/packages_and_registries/virtual_registries/graphql/providers/registries_and_upstreams';
import getRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql';
import getUpstreamRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_registries.query.graphql';
import getUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import i18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';
import MavenVirtualRegistriesAndUpstreamsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries_and_upstreams/index.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initSimpleApp(
  '#js-vue-maven-virtual-registries-and-upstreams',
  MavenVirtualRegistriesAndUpstreamsApp,
  {
    withApolloProvider: apolloProvider,
    name: 'MavenVirtualRegistriesAndUpstreamsRoot',
    additionalProvide: {
      i18n,
      ids: {
        baseUpstream: 'VirtualRegistries::Packages::Maven::Upstream',
      },
      getRegistriesQuery,
      getUpstreamsQuery,
      getUpstreamsCountQuery,
      getUpstreamRegistriesQuery,
    },
  },
);
