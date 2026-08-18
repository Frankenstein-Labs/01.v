import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import EditMavenUpstreamApp from 'ee/packages_and_registries/virtual_registries/pages/common/upstream/edit.vue';
import i18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';
import getUpstreamRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_registries.query.graphql';

initSimpleApp('#js-vue-virtual-registry-edit-maven-upstream', EditMavenUpstreamApp, {
  withApolloProvider: true,
  name: 'VirtualRegistryEditMavenUpstream',
  additionalProvide: {
    i18n,
    ids: {
      baseUpstream: 'VirtualRegistries::Packages::Maven::Upstream',
    },
    getUpstreamRegistriesQuery,
    isMavenUpstream: true,
  },
});
