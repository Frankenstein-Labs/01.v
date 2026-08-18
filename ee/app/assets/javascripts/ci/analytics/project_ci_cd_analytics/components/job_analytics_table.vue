<script>
import {
  GlTooltipDirective,
  GlAlert,
  GlLoadingIcon,
  GlTable,
  GlSearchBoxByClick,
  GlEmptyState,
} from '@gitlab/ui';
import CHART_EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import { __, s__, sprintf, formatNumber } from '~/locale';

import * as Sentry from '~/sentry/sentry_browser_wrapper';

import { getPaginationVariables } from '~/ci/runner/utils';
import RunnerPagination from '~/ci/runner/components/runner_pagination.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import { calculateRateDenominator } from '~/ci/analytics/utils';
import getJobAnalytics from '../graphql/queries/get_job_analytics.query.graphql';

import { durationField, numericField } from './table_utils';

export default {
  name: 'JobAnalyticsTable',
  components: {
    GlAlert,
    GlLoadingIcon,
    GlTable,
    GlSearchBoxByClick,
    GlEmptyState,
    RunnerPagination,
    HelpPopover,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glLicensedFeaturesMixin()],
  props: {
    variables: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['filters-input'],
  data() {
    return {
      jobName: this.variables.jobName || '',
      jobAnalytics: {
        error: null,
        items: [],
        pageInfo: {},
      },
      sort: {
        by: 'meanDuration',
        desc: true,
      },
      pagination: {},
    };
  },
  computed: {
    isJobAnalyticsAvailable() {
      return this.glLicensedFeatures?.ciJobAnalyticsForProjects;
    },
    isLoading() {
      return this.$apollo.queries.jobAnalytics.loading;
    },
    isEmpty() {
      return !this.isLoading && !this.jobAnalytics.items.length;
    },
    isEmptyMessage() {
      if (this.jobName) {
        return s__('CICD|No job data found for the current filter.');
      }
      return s__('CICD|No job data found.');
    },
  },
  apollo: {
    jobAnalytics: {
      query: getJobAnalytics,
      variables() {
        return {
          ...this.variables,
          ...this.getSortVariables(this.sort),
          ...getPaginationVariables(this.pagination, 5),
        };
      },
      skip() {
        return !this.isJobAnalyticsAvailable;
      },
      update(data) {
        try {
          const { nodes = [], pageInfo } = data?.project?.jobAnalytics || {};

          const items = nodes.map((node) => {
            const { statistics = {}, ...job } = node || {};
            const { durationStatistics = {}, ...otherStatistics } = statistics || {};

            return {
              ...job,
              ...otherStatistics,
              ...durationStatistics,
            };
          });

          return {
            error: null,
            items,
            pageInfo: pageInfo || {},
          };
        } catch (error) {
          this.onError(error);
          return {
            error,
            items: [],
            pageInfo: {},
          };
        }
      },
      error(e) {
        this.onError(e);
      },
    },
  },
  methods: {
    formatCount(countString, totalString) {
      // Counts are strings because they can contain very large numbers, use BigInt
      const count = BigInt(countString);
      const total = BigInt(totalString);
      return `${formatNumber(count)} / ${formatNumber(total)}`;
    },
    rateDenominator(item) {
      return calculateRateDenominator(item.successCount, item.failedCount, item.count);
    },
    onError(e) {
      Sentry.captureException(e);

      // Ensure the user can continue to use the panel by resetting the pagination
      this.pagination = {};
    },
    onPaginationInput(pagination) {
      this.pagination = pagination;
    },
    getSortVariables({ by = 'meanDuration', desc = false }) {
      const { sortPrefix } = this.$options.fields.find(({ key }) => key === by);
      return { sort: `${sortPrefix}${desc ? '_DESC' : '_ASC'}` };
    },
    onSortChanged({ sortBy, sortDesc }) {
      this.sort = {
        by: sortBy,
        desc: sortDesc,
      };
      this.pagination = {};
    },
    onJobNameInput(value) {
      if (this.jobName === value) {
        // Refresh results even if no filters changed
        // Useful to get latest data or recover from errors
        this.$apollo.queries.jobAnalytics.refetch();
        return;
      }
      this.jobName = value;
      this.pagination = {};
      this.$emit('filters-input', { ...this.variables, jobName: this.jobName });
    },
    onJobNameClear() {
      this.onJobNameInput('');
    },
  },
  failureRatePopover: {
    title: s__('Job|How this is calculated?'),
    content: s__(
      "Job|Rate = failed_jobs / (success + failed). Canceled and skipped jobs aren't included. Success rate is the inverse.",
    ),
  },
  fields: [
    {
      key: 'name',
      label: __('Job'),
      sortable: true,
      sortPrefix: 'NAME', // Prefix of CiJobAnalyticsSort
    },
    {
      key: 'stageName',
      label: __('Stage'),
      sortable: true,
      sortPrefix: 'STAGE_NAME', // Prefix of CiJobAnalyticsSort
    },
    {
      key: 'meanDuration',
      sortPrefix: 'MEAN_DURATION', // Prefix of CiJobAnalyticsSort
      label: s__('Job|Mean duration'),
      ...durationField(),
    },
    {
      key: 'p95Duration',
      sortPrefix: 'P95_DURATION', // eslint-disable-line @gitlab/require-i18n-strings -- Prefix of CiJobAnalyticsSort, not translatable
      label: s__('Job|P95 duration'),
      ...durationField(),
    },
    {
      key: 'failedRate',
      sortPrefix: 'FAILED_RATE', // Prefix of CiJobAnalyticsSort
      label: sprintf(s__('Job|Failure rate (%{percentSymbol})'), { percentSymbol: '%' }),
      ...numericField(),
    },
    {
      key: 'successRate',
      sortPrefix: 'SUCCESS_RATE', // Prefix of CiJobAnalyticsSort
      label: sprintf(s__('Job|Success rate (%{percentSymbol})'), { percentSymbol: '%' }),
      ...numericField(),
    },
  ],
  CHART_EMPTY_STATE_SVG_URL,
};
</script>

<template>
  <div v-if="isJobAnalyticsAvailable" class="gl-border gl-border-default gl-p-5">
    <h3 class="gl-heading-4">{{ s__('CICD|Jobs') }}</h3>
    <gl-alert
      v-if="jobAnalytics.error"
      class="gl-mb-4"
      variant="danger"
      @dismiss="jobAnalytics.error = null"
    >
      {{ s__('CICD|Unable to load job data. Please try again.') }}
    </gl-alert>
    <gl-search-box-by-click
      :value="jobName"
      :placeholder="s__('CICD|Search by job name')"
      class="gl-mb-4"
      @submit="onJobNameInput"
      @clear="onJobNameClear"
    />

    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mb-5" />
    <gl-empty-state
      v-else-if="isEmpty"
      :svg-path="$options.CHART_EMPTY_STATE_SVG_URL"
      :description="isEmptyMessage"
    />
    <gl-table
      v-else
      :fields="$options.fields"
      :items="jobAnalytics.items"
      :no-local-sorting="true"
      :sort-by="sort.by"
      :sort-desc="sort.desc"
      @sort-changed="onSortChanged"
    >
      <template #head(failedRate)="{ label }">
        <span class="gl-inline-flex gl-items-center gl-gap-2">
          {{ label }}
          <help-popover
            :options="$options.failureRatePopover"
            icon="information-o"
            trigger-class="gl-text-subtle"
            data-testid="failure-rate-help-popover"
          />
        </span>
      </template>
      <template #cell(failedRate)="{ item, value }">
        <span v-gl-tooltip="formatCount(item.failedCount, rateDenominator(item))">{{ value }}</span>
      </template>
      <template #cell(successRate)="{ item, value }">
        <span v-gl-tooltip="formatCount(item.successCount, rateDenominator(item))">{{
          value
        }}</span>
      </template>
    </gl-table>
    <runner-pagination
      class="gl-mt-3"
      :disabled="isLoading"
      :page-info="jobAnalytics.pageInfo"
      @input="onPaginationInput"
    />
  </div>
</template>
