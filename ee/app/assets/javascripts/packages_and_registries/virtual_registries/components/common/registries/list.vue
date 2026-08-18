<script>
import { GlAlert, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import RegistriesTable from 'ee_component/packages_and_registries/virtual_registries/components/common/registries/table.vue';

const PAGE_SIZE = 20;
const INITIAL_VALUE = [];

export default {
  name: 'RegistriesList',
  components: {
    GlAlert,
    GlEmptyState,
    GlSkeletonLoader,
    RegistriesTable,
  },
  inject: ['fullPath', 'getRegistriesQuery', 'i18n'],
  emits: ['update-count'],
  data() {
    return {
      alertMessage: '',
      isLoading: 0,
      registries: INITIAL_VALUE,
    };
  },
  computed: {
    hasRegistries() {
      return this.registries.length > 0;
    },
    queryVariables() {
      return {
        groupPath: this.fullPath,
        first: PAGE_SIZE,
      };
    },
  },
  apollo: {
    registries: {
      query() {
        return this.getRegistriesQuery;
      },
      loadingKey: 'isLoading',
      variables() {
        return this.queryVariables;
      },
      update: (data) => data.group?.registries?.nodes ?? [],
      result() {
        this.$emit('update-count', this.registries.length);
      },
      error(error) {
        this.alertMessage =
          error.message || s__('VirtualRegistry|Failed to fetch list of virtual registries.');
        captureException({ error, component: this.$options.name });
      },
    },
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
  <gl-alert v-if="alertMessage" variant="danger">
    {{ alertMessage }}
  </gl-alert>
  <gl-skeleton-loader v-else-if="isLoading" :lines="2" :width="500" class="gl-mt-4" />
  <div v-else-if="hasRegistries">
    <registries-table :registries="registries" />
  </div>
  <gl-empty-state
    v-else
    :svg-path="$options.emptyStateIllustrationUrl"
    :title="i18n.registries.emptyStateTitle"
  />
</template>
