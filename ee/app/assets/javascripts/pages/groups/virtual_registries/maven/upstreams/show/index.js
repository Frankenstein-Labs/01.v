import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenUpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/common/upstream/show.vue';
import i18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';
import getUpstreamCacheEntriesCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries_count.query.graphql';
import getUpstreamCacheEntriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries.query.graphql';

initSimpleApp('#js-vue-maven-upstream-details', MavenUpstreamDetailsApp, {
  withApolloProvider: true,
  name: 'MavenUpstreamDetails',
  additionalProvide: {
    i18n,
    ids: {
      baseUpstream: 'VirtualRegistries::Packages::Maven::Upstream',
    },
    getUpstreamCacheEntriesCountQuery,
    getUpstreamCacheEntriesQuery,
  },
});
