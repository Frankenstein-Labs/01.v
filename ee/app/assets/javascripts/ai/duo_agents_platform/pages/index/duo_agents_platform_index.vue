<script>
import { GlSkeletonLoader, GlFilteredSearchToken, GlCollapsibleListbox } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import {
  AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES,
  AGENT_PLATFORM_SESSION_RETENTION_LENGTH,
} from 'ee/ai/duo_agents_platform/constants';
import getFlowTypesQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_flow_types.query.graphql';
import NoCreditsBanner from '../../components/common/no_credits_banner.vue';
import UsageBillingForbiddenBanner from '../../components/common/usage_billing_forbidden_banner.vue';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    AgentFlowList,
    FilteredSearchBar,
    GlSkeletonLoader,
    GlCollapsibleListbox,
    PageHeading,
    NoCreditsBanner,
    UsageBillingForbiddenBanner,
  },
  inject: {
    isSidePanelView: { default: false },
    creditsAvailable: { default: true },
    billingForbidden: { default: false },
  },
  props: {
    hasInitialWorkflows: {
      required: true,
      type: Boolean,
    },
    initialSort: {
      required: true,
      type: String,
    },
    isLoadingWorkflows: {
      required: true,
      type: Boolean,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  emits: ['query-variables-updated'],
  data() {
    return {
      currentFilters: [],
      currentSort: this.initialSort,
      paginationVariables: {},
      filterVariables: {},
      timeRangeFilter: 'all',
      flowTypes: [],
    };
  },
  apollo: {
    flowTypes: {
      query: getFlowTypesQuery,
      update(data) {
        return (
          data.aiCatalogItems?.nodes
            ?.filter((item) => item.foundationalFlowReference)
            .map((item) => ({
              value: item.foundationalFlowReference,
              title: item.name,
            })) || []
        );
      },
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch flow types'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    showEmptyState() {
      return !this.hasInitialWorkflows;
    },
    processedFiltersForGraphQL() {
      const FILTER_TYPE_MAP = {
        'flow-name': 'type',
        'flow-status-group': 'statusGroup',
        [FILTERED_SEARCH_TERM]: 'search',
      };

      return this.currentFilters
        .filter((filter) => filter.value?.data && FILTER_TYPE_MAP[filter.type])
        .reduce((acc, filter) => {
          const mappedProperty = FILTER_TYPE_MAP[filter.type];
          acc[mappedProperty] = filter.value.data;
          return acc;
        }, {});
    },
    selectedTimeRangeText() {
      return this.$options.timeRangeOptions.find((opt) => opt.value === this.timeRangeFilter)?.text;
    },
    flowNameToken() {
      return {
        type: 'flow-name',
        title: s__('DuoAgentsPlatform|Flow'),
        icon: 'flow-ai',
        token: GlFilteredSearchToken,
        operators: OPERATORS_IS,
        unique: true,
        options: this.flowTypes,
      };
    },
    computedTokens() {
      const tokens = [];

      if (this.flowTypes.length > 0) {
        tokens.push(this.flowNameToken);
      }

      tokens.push({
        type: 'flow-status-group',
        title: __('Status'),
        icon: 'status',
        token: GlFilteredSearchToken,
        operators: OPERATORS_IS,
        unique: true,
        options: [
          { value: 'ACTIVE', title: __('Active') },
          { value: 'PAUSED', title: __('Paused') },
          { value: 'AWAITING_INPUT', title: __('Awaiting input') },
          { value: 'COMPLETED', title: __('Completed') },
          { value: 'FAILED', title: __('Failed') },
          { value: 'CANCELED', title: __('Canceled') },
        ],
      });

      return tokens;
    },
  },
  methods: {
    handleNextPage() {
      const paginationVars = {
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      };
      this.handlePagination(paginationVars);
    },
    handlePrevPage() {
      const paginationVars = {
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      };
      this.handlePagination(paginationVars);
    },
    handlePagination(paginationVars) {
      this.paginationVariables = paginationVars;
      this.emitVariables();
    },
    resetPaginationAndEmit() {
      this.handlePagination(DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES);
    },
    handleSort(sortBy) {
      this.currentSort = sortBy;
      this.resetPaginationAndEmit();
    },
    handleFilter(filters) {
      this.currentFilters = filters;
      this.refetchWithFilters(this.processedFiltersForGraphQL);
    },
    refetchWithFilters(filters) {
      this.filterVariables = filters;
      this.resetPaginationAndEmit();
    },
    emitVariables() {
      let updatedAfter = null;

      if (this.timeRangeFilter === 'available') {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - AGENT_PLATFORM_SESSION_RETENTION_LENGTH);
        updatedAfter = thirtyDaysAgo.toISOString();
      }

      this.$emit('query-variables-updated', {
        sort: this.currentSort,
        pagination: this.paginationVariables,
        filters: this.filterVariables,
        updatedAfter,
      });
    },
    handleTimeRangeChange(value) {
      this.timeRangeFilter = value;
      this.resetPaginationAndEmit();
    },
  },
  emptyStateIllustrationPath,
  availableSortOptions: [
    {
      id: 1,
      title: __('Created date'),
      sortDirection: {
        descending: 'CREATED_DESC',
        ascending: 'CREATED_ASC',
      },
    },
    {
      id: 2,
      title: __('Updated date'),
      sortDirection: {
        descending: 'UPDATED_DESC',
        ascending: 'UPDATED_ASC',
      },
    },
  ],
  timeRangeOptions: [
    { value: 'all', text: __('All') },
    { value: 'available', text: s__('DuoAgentsPlatform|Available') },
  ],
};
</script>
<template>
  <div class="gl-min-h-full gl-flex-wrap gl-justify-center" data-testid="agent-sessions">
    <page-heading v-if="!isSidePanelView" :heading="s__('DuoAgentsPlatform|Sessions')" />
    <usage-billing-forbidden-banner v-if="!creditsAvailable && billingForbidden" />
    <no-credits-banner v-else-if="!creditsAvailable" />
    <filtered-search-bar
      v-if="hasInitialWorkflows"
      namespace="duo-agents-platform"
      :tokens="computedTokens"
      :search-input-placeholder="s__('DuoAgentsPlatform|Search for a session')"
      :sort-options="$options.availableSortOptions"
      :initial-sort-by="initialSort"
      :initial-sort="initialSort"
      recent-searches-storage-key="agent-sessions"
      sync-filter-and-sort
      terms-as-tokens
      class="gl-grow gl-border-t-0 gl-p-4"
      data-testid="agent-sessions-search-container"
      @on-filter="handleFilter"
      @on-sort="handleSort"
    >
      <template #time-range-filter>
        <gl-collapsible-listbox
          data-testid="time-range-filter"
          :items="$options.timeRangeOptions"
          :selected="timeRangeFilter"
          :toggle-text="selectedTimeRangeText"
          @select="handleTimeRangeChange"
        />
      </template>
    </filtered-search-bar>
    <div
      v-if="isLoadingWorkflows"
      class="gl-flex gl-w-full gl-flex-col gl-gap-5 gl-p-5"
      data-testid="loading-container"
    >
      <gl-skeleton-loader :lines="2" :width="300" />
      <gl-skeleton-loader :lines="2" :width="300" />
      <gl-skeleton-loader :lines="2" :width="300" />
    </div>
    <agent-flow-list
      v-else
      :show-project-info="isSidePanelView"
      :show-empty-state="showEmptyState"
      :initial-sort="initialSort"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
