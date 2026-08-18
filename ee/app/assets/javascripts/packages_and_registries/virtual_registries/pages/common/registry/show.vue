<script>
import { GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import RegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/header.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/upstreams_list.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'RegistryShow',
  components: {
    GlEmptyState,
    GlSkeletonLoader,
    RegistryDetailsHeader,
    UpstreamsList,
  },
  inject: {
    initialRegistry: { default: {} },
    getRegistryQuery: { default: null },
    getRegistryUpstreamsQuery: { default: null },
    ids: { default: {} },
  },
  props: {
    id: {
      type: [Number, String],
      default: null,
      required: false,
    },
  },
  apollo: {
    registry: {
      query() {
        return this.getRegistryQuery;
      },
      variables() {
        return {
          id: this.registryGlobalId,
        };
      },
      update(data) {
        return data.registry || null;
      },
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch registry details.'),
        });

        captureException({ error, component: this.$options.name });
      },
    },
    registryUpstreams: {
      query() {
        return this.getRegistryUpstreamsQuery;
      },
      variables() {
        return {
          id: this.registryGlobalId,
        };
      },
      update(data) {
        return data.registry?.registryUpstreams || [];
      },
      result() {
        this.hasLoadedOnce = true;
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  data() {
    return {
      registry: null,
      hasLoadedOnce: false,
      registryUpstreams: [],
    };
  },
  computed: {
    isFirstTimeLoading() {
      return this.$apollo.queries.registryUpstreams.loading && !this.hasLoadedOnce;
    },
    registryGlobalId() {
      return convertToGraphQLId(this.ids.baseRegistry, this.id || this.initialRegistry.id);
    },
  },
  methods: {
    refetchRegistryUpstreamsQuery() {
      this.$apollo.queries.registryUpstreams.refetch();
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <gl-skeleton-loader
      v-if="$apollo.queries.registry.loading"
      :lines="2"
      :width="500"
      class="gl-mt-4"
    />
    <template v-else-if="registry">
      <registry-details-header :registry="registry" />
      <upstreams-list
        :id="registry.id"
        :loading="isFirstTimeLoading"
        :registry-upstreams="registryUpstreams"
        @update="refetchRegistryUpstreamsQuery"
      />
    </template>
    <gl-empty-state
      v-else
      :title="s__('Virtual registry|Registry not found.')"
      :svg-path="$options.emptySearchSvg"
    />
  </div>
</template>
