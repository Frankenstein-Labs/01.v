<script>
import { GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RegistryForm from 'ee/packages_and_registries/virtual_registries/components/registry/form.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'RegistryEditPage',
  components: {
    GlEmptyState,
    GlSkeletonLoader,
    PageHeading,
    RegistryForm,
  },
  inject: ['getRegistryQuery', 'i18n', 'ids'],
  props: {
    id: {
      type: [Number, String],
      required: true,
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
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch registry details.'),
        });

        captureException({ error, component: this.$options.name });
      },
    },
  },
  data() {
    return {
      registry: null,
    };
  },
  computed: {
    registryGlobalId() {
      return convertToGraphQLId(this.ids.baseRegistry, this.id);
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
      <page-heading :heading="i18n.editRegistryPageTitle" />
      <registry-form :initial-registry="registry" :registry-id="registry.id" />
    </template>
    <gl-empty-state
      v-else
      :title="s__('Virtual registry|Registry not found.')"
      :svg-path="$options.emptySearchSvg"
    />
  </div>
</template>
