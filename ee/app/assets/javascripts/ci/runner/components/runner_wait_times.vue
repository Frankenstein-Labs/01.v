<script>
import { GlEmptyState, GlLink, GlLoadingIcon, GlSkeletonLoader } from '@gitlab/ui';
import { GlSingleStat, GlLineChart } from '@gitlab/ui/src/charts';
import CHART_EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { formatDate } from '~/lib/utils/datetime_utility';

import {
  formatSeconds,
  runnerWaitTimeQueryData,
  runnerWaitTimeHistoryQueryData,
} from 'ee/ci/runner/runner_performance_utils';

export default {
  name: 'RunnerWaitTimes',
  components: {
    HelpPopover,
    GlEmptyState,
    GlLink,
    GlLoadingIcon,
    GlSkeletonLoader,
    GlSingleStat,
    GlLineChart,
  },
  props: {
    waitTimesPopoverDescription: {
      type: String,
      required: true,
    },
    waitTimes: {
      type: Object,
      required: false,
      default: null,
    },
    waitTimesLoading: {
      type: Boolean,
      required: false,
      default: false,
    },

    waitTimeHistoryEmptyStateDescription: {
      type: String,
      required: true,
    },
    waitTimeHistoryEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    waitTimeHistory: {
      type: Array,
      required: false,
      default: () => [],
    },
    waitTimeHistoryLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    waitTimesStatsData() {
      return runnerWaitTimeQueryData(this.waitTimes);
    },
    waitTimeHistoryChartData() {
      return runnerWaitTimeHistoryQueryData(this.waitTimeHistory);
    },
  },
  methods: {
    formatSeconds(value) {
      return formatSeconds(value);
    },
  },
  jobDurationHelpPagePath: helpPagePath('ci/runners/runners_scope', {
    anchor: 'view-statistics-for-runner-performance',
  }),
  chartOption: {
    xAxis: {
      name: s__('Runners|UTC Time'),
      type: 'time',
      axisLabel: {
        formatter: (value) => formatDate(value, 'HH:MM', true),
      },
    },
    yAxis: {
      name: s__('Runners|Wait time (secs)'),
    },
  },
  CHART_EMPTY_STATE_SVG_URL,
};
</script>
<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <div class="gl-flex">
      <h2 class="gl-mt-0 gl-text-lg">
        {{ s__('Runners|Wait time to pick a job') }}
        <help-popover trigger-class="gl-align-baseline">
          {{ waitTimesPopoverDescription }}
          <gl-link :href="$options.jobDurationHelpPagePath">{{
            s__('Runners|How is this calculated?')
          }}</gl-link>
        </help-popover>
      </h2>
      <gl-loading-icon v-if="waitTimesLoading || waitTimeHistoryLoading" class="gl-ml-auto" />
    </div>

    <div class="gl-flex gl-flex-wrap gl-gap-3">
      <gl-single-stat
        v-for="stat in waitTimesStatsData"
        :key="stat.key"
        :title="stat.title"
        :value="stat.value"
        :unit="s__('Units|sec')"
      />
    </div>
    <div v-if="waitTimeHistoryEnabled">
      <div
        v-if="waitTimeHistoryLoading && !waitTimeHistoryChartData.length"
        class="gl-flex gl-items-center gl-justify-center gl-py-4"
      >
        <gl-skeleton-loader :equal-width-lines="true" />
      </div>
      <gl-empty-state
        v-else-if="!waitTimeHistoryChartData.length"
        :svg-path="$options.CHART_EMPTY_STATE_SVG_URL"
        :description="waitTimeHistoryEmptyStateDescription"
      />
      <gl-line-chart
        v-else
        :include-legend-avg-max="false"
        :data="waitTimeHistoryChartData"
        :option="$options.chartOption"
      >
        <template #tooltip-value="{ value }">{{ formatSeconds(value) }}</template>
      </gl-line-chart>
    </div>
  </div>
</template>
