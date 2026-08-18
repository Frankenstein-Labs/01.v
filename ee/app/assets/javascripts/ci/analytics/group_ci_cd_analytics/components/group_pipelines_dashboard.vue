<script>
import { GlDashboardLayout } from '@gitlab/ui';
import { updateQueryHistory, paramsFromQuery } from '~/ci/analytics/url_utils';
import { calculateDatesFromRelativeDays } from '~/ci/analytics/utils';
import { DATE_RANGES_AS_DAYS, DATE_RANGE_DEFAULT } from '~/ci/analytics/constants';

import GroupDashboardFilters from './group_pipelines_dashboard_filters.vue';

export default {
  name: 'GroupPipelinesDashboard',
  components: {
    GlDashboardLayout,
    GroupDashboardFilters,
  },
  data() {
    const defaultParams = {
      dateRange: DATE_RANGE_DEFAULT,
    };

    return {
      defaultParams,
      params: paramsFromQuery(window.location.search, defaultParams),
    };
  },
  computed: {
    dashboardConfig() {
      return {
        panels: [
          // empty, in development
        ],
      };
    },
    // eslint-disable-next-line vue/no-unused-properties -- Will be used when Apollo data is added
    variables() {
      const { fromTime, toTime } = calculateDatesFromRelativeDays(
        DATE_RANGES_AS_DAYS[this.params.dateRange] || 7,
      );

      return {
        fromTime,
        toTime,
      };
    },
  },
  methods: {
    onFiltersInput(params) {
      this.params = { ...this.params, ...params };

      updateQueryHistory(this.params, this.defaultParams);
    },
  },
};
</script>
<template>
  <div>
    <gl-dashboard-layout :config="dashboardConfig">
      <template #filters>
        <group-dashboard-filters :value="params" @input="onFiltersInput($event)" />
      </template>
    </gl-dashboard-layout>
  </div>
</template>
