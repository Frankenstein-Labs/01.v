<script>
import { GlAlert, GlCollapsibleListbox, GlFormGroup, GlLoadingIcon } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getMonthNames, formatIso8601Date } from '~/lib/utils/datetime_utility';
import getDedicatedInstanceUsageByYear from './graphql/queries/dedicated_instance_usage_by_year.query.graphql';
import getDedicatedInstanceUsageByMonth from './graphql/queries/dedicated_instance_usage_by_month.query.graphql';
import getDedicatedInstanceRunnerFilters from './graphql/queries/dedicated_instance_runner_filters.query.graphql';
import { GROUPING_INSTANCE_AGGREGATE, GROUPING_PER_ROOT_NAMESPACE } from './constants';
import VisualizationFilters from './components/shared/visualization_filters.vue';
import RunnerUsageHeader from './components/runner_usage_header.vue';
import MinutesUsagePerMonth from './components/visualization_types/minutes_usage_per_month.vue';
import MinutesUsageByNamespace from './components/visualization_types/minutes_usage_by_namespace.vue';

export default {
  name: 'PipelinesAdminApp',
  components: {
    GlAlert,
    GlCollapsibleListbox,
    GlFormGroup,
    GlLoadingIcon,
    RunnerUsageHeader,
    MinutesUsagePerMonth,
    MinutesUsageByNamespace,
    VisualizationFilters,
  },
  data() {
    const lastResetDate = new Date(); // TODO: Get last reset date
    const year = lastResetDate.getUTCFullYear();
    const month = lastResetDate.getUTCMonth();

    return {
      error: '',
      year,
      selectedMonth: month, // 0-based month index
      currentMonth: month, // This is to separate the one from the dropdown and the one from the single stat
      ciDedicatedInstanceRunnerUsage: [],
      dedicatedInstanceRunnerUsageMonth: [],
      runnerFilters: null,
      selectedYear: new Date().getFullYear(),
      selectedRunnerForMonth: null,
      selectedRunnerNamespace: null,
    };
  },
  apollo: {
    ciDedicatedInstanceRunnerUsage: {
      query: getDedicatedInstanceUsageByYear,
      variables() {
        return {
          grouping: GROUPING_INSTANCE_AGGREGATE,
          year: this.selectedYear,
          runnerId: this.selectedRunnerForMonth,
        };
      },
      update(res) {
        return res?.ciDedicatedHostedRunnerUsage?.nodes || [];
      },
      error(error) {
        this.error = s__('UsageQuota|Something went wrong while fetching compute usage');
        logError(
          'PipelineAdminUsageApp: error fetching getDedicatedInstanceUsageByYear query.',
          error,
        );
      },
    },
    dedicatedInstanceRunnerUsageMonth: {
      query: getDedicatedInstanceUsageByMonth,
      variables() {
        return {
          grouping: GROUPING_PER_ROOT_NAMESPACE,
          month: this.selectedDateInIso8601,
          runnerId: this.selectedRunnerNamespace,
        };
      },
      update(res) {
        return res?.ciDedicatedHostedRunnerUsage?.nodes || [];
      },
      error(error) {
        this.error = s__('UsageQuota|Something went wrong while fetching compute usage');
        logError(
          'PipelineAdminUsageApp: error fetching getDedicatedInstanceUsageByMonth query.',
          error,
        );
      },
    },
    runnerFilters: {
      query: getDedicatedInstanceRunnerFilters,
      update(res) {
        const allRunners = [
          ...(res?.ciDedicatedHostedRunnerFilters?.runners.nodes || []),
          ...(res?.ciDedicatedHostedRunnerFilters?.deletedRunners.nodes || []),
        ];

        if (allRunners.length >= 0) {
          this.selectedRunnerForMonth = allRunners[0].id;
          this.selectedRunnerNamespace = allRunners[0].id;
        }

        return {
          years: res?.ciDedicatedHostedRunnerFilters?.years || [],
          runners: allRunners || [],
        };
      },
      error(error) {
        this.error = s__('UsageQuota|Something went wrong while fetching runner filters');
        logError(
          'PipelineAdminUsageApp: error fetching getDedicatedInstanceRunnerFilters query.',
          error,
        );
      },
    },
  },
  computed: {
    selectedDateInIso8601() {
      return formatIso8601Date(this.year, this.selectedMonth, 1);
    },
    years() {
      return this.runnerFilters.years.map((year) => ({
        text: String(year),
        value: year,
      }));
    },
    runners() {
      return this.runnerFilters.runners.map((runner) => ({
        text: `#${getIdFromGraphQLId(runner.id)} - ${runner.description?.length ? runner.description : __('Runner')}`,
        value: runner.id,
      }));
    },
    months() {
      return getMonthNames().map((month, index) => ({
        text: month,
        value: index,
      }));
    },
    isLoadingYearUsageData() {
      return this.$apollo.queries.ciDedicatedInstanceRunnerUsage.loading;
    },
    isLoadingRunnerFilters() {
      return this.$apollo.queries.runnerFilters.loading;
    },
    isLoadingMonthlyUsageData() {
      return this.$apollo.queries.dedicatedInstanceRunnerUsageMonth.loading;
    },
    monthlyUsage() {
      return this.dedicatedInstanceRunnerUsageMonth[this.currentMonth]?.computeMinutesUsage || 0;
    },
  },
  methods: {
    clearError() {
      this.error = '';
    },
    updateSelectedRunnerUsageByMonth(runner) {
      this.selectedRunnerForMonth = runner;
    },
    updatedSelectedRunnerUsageByNamespace(runner) {
      this.selectedRunnerNamespace = runner;
    },
  },
};
</script>
<template>
  <div>
    <runner-usage-header :loading="isLoadingMonthlyUsageData" :monthly-usage="monthlyUsage" />

    <gl-alert v-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>

    <section class="gl-my-5">
      <h3 class="gl-heading-3 gl-mb-5">{{ s__('UsageQuota|Usage by month') }}</h3>
      <gl-loading-icon v-if="isLoadingRunnerFilters" />
      <template v-else>
        <visualization-filters
          :runners="runners"
          @runner-selected="updateSelectedRunnerUsageByMonth"
        >
          <gl-form-group class="gl-mr-4" :label="__('Year')">
            <gl-collapsible-listbox
              v-model="selectedYear"
              :items="years"
              block
              data-testid="runner-year-filter"
            />
          </gl-form-group>
        </visualization-filters>
      </template>
      <div v-if="isLoadingYearUsageData" class="gl-flex gl-items-center gl-justify-center">
        <gl-loading-icon size="lg" data-testid="compute-usage-chart-loading-indicator" />
      </div>
      <minutes-usage-per-month v-else :usage-data="ciDedicatedInstanceRunnerUsage" />
    </section>

    <section class="gl-my-5">
      <h3 class="gl-heading-3 gl-mb-5">{{ s__('UsageQuota|Usage by namespace') }}</h3>
      <gl-loading-icon v-if="isLoadingRunnerFilters" />
      <template v-else>
        <visualization-filters
          :runners="runners"
          @runner-selected="updatedSelectedRunnerUsageByNamespace"
        >
          <gl-form-group class="gl-mr-4" :label="__('Month')">
            <gl-collapsible-listbox
              v-model="selectedMonth"
              :items="months"
              data-testid="filter-usage-month-dropdown"
              block
            />
          </gl-form-group>
        </visualization-filters>
      </template>
      <minutes-usage-by-namespace :usage-data="dedicatedInstanceRunnerUsageMonth" />
    </section>
  </div>
</template>
