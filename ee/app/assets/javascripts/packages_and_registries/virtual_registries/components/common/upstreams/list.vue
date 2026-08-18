<script>
import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import emptyStateIllustrationUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-radar-md.svg?url';
import { s__ } from '~/locale';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import UpstreamsTable from './table.vue';

export default {
  name: 'UpstreamsList',
  components: {
    EmptyResult,
    GlAlert,
    GlEmptyState,
    GlFilteredSearch,
    GlKeysetPagination,
    GlSkeletonLoader,
    UpstreamsTable,
  },
  inject: ['i18n'],
  props: {
    upstreams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    searchTerm: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['page-change', 'submit', 'upstream-deleted'],
  data() {
    return {
      alertMessage: '',
      upstreamDeleteSuccessMessage: '',
    };
  },
  computed: {
    filteredSearchValue() {
      return [
        {
          type: 'filtered-search-term',
          value: { data: this.searchTerm || '' },
        },
      ];
    },
    hasSearchTerm() {
      return Boolean(this.searchTerm?.length);
    },
    showUpstreamsTable() {
      return this.hasUpstreams || this.hasSearchTerm;
    },
    pageInfo() {
      return this.upstreams.pageInfo;
    },
    hasUpstreams() {
      return this.upstreams.nodes.length > 0;
    },
  },
  methods: {
    handleNextPage() {
      this.$emit('page-change', { after: this.pageInfo.endCursor });
    },
    handlePreviousPage() {
      this.$emit('page-change', { before: this.pageInfo.startCursor });
    },
    clearSearch() {
      this.$emit('submit', null);
    },
    searchUpstreams(filters) {
      const [searchTerm] = filters;
      this.$emit('submit', searchTerm);
    },
    handleUpstreamDelete() {
      this.upstreamDeleteSuccessMessage = s__('VirtualRegistry|Upstream has been deleted.');
      this.$emit('upstream-deleted');
    },
    setAlertMessage(message = '') {
      this.alertMessage = message;
    },
  },
  emptyStateIllustrationUrl,
};
</script>

<template>
  <div>
    <gl-alert v-if="upstreamDeleteSuccessMessage" @dismiss="upstreamDeleteSuccessMessage = ''">
      {{ upstreamDeleteSuccessMessage }}
    </gl-alert>
    <div v-if="showUpstreamsTable">
      <div
        class="gl-flex gl-flex-col gl-gap-3 gl-border-y-0 gl-bg-subtle gl-p-5 @md/panel:gl-flex-row"
      >
        <gl-filtered-search
          class="gl-min-w-0 gl-grow"
          :placeholder="__('Filter results')"
          :search-text-option-label="__('Search for this text')"
          :value="filteredSearchValue"
          terms-as-tokens
          @submit="searchUpstreams"
          @clear="clearSearch"
        />
      </div>
      <gl-alert v-if="alertMessage" variant="danger" @dismiss="setAlertMessage">
        {{ alertMessage }}
      </gl-alert>
      <upstreams-table
        v-if="hasUpstreams"
        :upstreams="upstreams.nodes"
        :busy="loading"
        @upstream-deleted="handleUpstreamDelete"
        @upstream-delete-failed="setAlertMessage"
      />
      <empty-result v-else />
      <div class="gl-flex gl-justify-center">
        <gl-keyset-pagination v-bind="pageInfo" @next="handleNextPage" @prev="handlePreviousPage" />
      </div>
    </div>
    <div v-else>
      <gl-alert v-if="alertMessage" variant="danger" :dismissible="false">
        {{ alertMessage }}
      </gl-alert>
      <gl-skeleton-loader v-else-if="loading" :lines="2" :width="500" class="gl-mt-4" />
      <gl-empty-state
        v-else
        :svg-path="$options.emptyStateIllustrationUrl"
        :title="i18n.upstreams.emptyStateTitle"
        :description="i18n.upstreams.emptyStateDescription"
      />
    </div>
  </div>
</template>
