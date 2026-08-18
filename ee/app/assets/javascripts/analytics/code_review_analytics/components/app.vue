<script>
import { GlBadge, GlLoadingIcon, GlEmptyState, GlPagination } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import FilterBar from './filter_bar.vue';
import MergeRequestTable from './merge_request_table.vue';

export default {
  name: 'CodeReviewAnalyticsApp',
  components: {
    GlBadge,
    GlLoadingIcon,
    GlPagination,
    GlEmptyState,
    FilterBar,
    MergeRequestTable,
  },
  props: {
    projectId: {
      type: Number,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    newMergeRequestUrl: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateSvgPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState('mergeRequests', {
      isLoading: 'isLoading',
      perPage: (state) => state.pageInfo.perPage,
      totalItems: (state) => state.pageInfo.total,
      page: (state) => state.pageInfo.page,
    }),
    currentPage: {
      get() {
        return this.page;
      },
      set(newVal) {
        this.setPage(newVal);
        this.fetchMergeRequests();
      },
    },
  },
  created() {
    this.setProjectId(this.projectId);
    this.fetchMergeRequests();
  },
  methods: {
    ...mapActions('mergeRequests', ['setProjectId', 'fetchMergeRequests', 'setPage']),
  },
};
</script>

<template>
  <div>
    <filter-bar :project-path="projectPath" />
    <div class="gl-mt-3">
      <gl-loading-icon v-show="isLoading" size="lg" class="gl-mt-5" />
      <template v-if="!isLoading">
        <gl-empty-state
          v-if="!totalItems"
          :title="__(`No open merge requests`)"
          :primary-button-text="__('New merge request')"
          :primary-button-link="newMergeRequestUrl"
          :svg-path="emptyStateSvgPath"
          :svg-height="150"
        >
          <template #description>
            <div class="gl-text-center">
              <p>{{ __('Create a merge request, or edit your criteria and try again.') }}</p>
            </div>
          </template>
        </gl-empty-state>
        <template v-else>
          <div>
            <span class="gl-font-bold">{{ __('Merge Requests in Review') }}</span>
            <gl-badge>{{ totalItems }}</gl-badge>
          </div>
          <merge-request-table />
          <gl-pagination
            v-model="currentPage"
            :per-page="perPage"
            :total-items="totalItems"
            align="center"
            class="gl-w-full"
          />
        </template>
      </template>
    </div>
  </div>
</template>
