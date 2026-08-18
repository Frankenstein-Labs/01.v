<script>
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';

import { runnerWaitTimeHistoryRange } from 'ee/ci/runner/runner_performance_utils';
import runnerWaitTimesQuery from 'ee/ci/runner/graphql/performance/runner_wait_times.query.graphql';
import runnerWaitTimeHistoryQuery from 'ee/ci/runner/graphql/performance/runner_wait_time_history.query.graphql';

import RunnerWaitTimes from '../components/runner_wait_times.vue';

export default {
  name: 'AdminRunnersWaitTimes',
  components: {
    RunnerWaitTimes,
  },
  inject: {
    clickhouseCiAnalyticsAvailable: {
      default: false,
    },
  },
  data() {
    return {
      waitTimes: null,
      waitTimeHistory: [],
    };
  },
  apollo: {
    waitTimes: {
      query: runnerWaitTimesQuery,
      update({ runners }) {
        return runners?.jobsStatistics?.queuedDuration;
      },
      error(error) {
        this.handlerError(error);
      },
    },
    waitTimeHistory: {
      query: runnerWaitTimeHistoryQuery,
      skip() {
        return !this.isHistoryFeatureEnabled;
      },
      variables() {
        return runnerWaitTimeHistoryRange();
      },
      update({ ciQueueingHistory }) {
        return ciQueueingHistory?.timeSeries;
      },
      error(error) {
        this.handlerError(error);
      },
    },
  },
  computed: {
    isHistoryFeatureEnabled() {
      return this.clickhouseCiAnalyticsAvailable;
    },
    waitTimesLoading() {
      return this.$apollo.queries.waitTimes.loading;
    },
    waitTimeHistoryLoading() {
      return this.$apollo.queries.waitTimeHistory.loading;
    },
  },
  methods: {
    handlerError(error) {
      createAlert({ message: error.message });
      captureException(error);
    },
  },
};
</script>
<template>
  <runner-wait-times
    :wait-times-popover-description="
      s__(
        'Runners|The time it takes for an instance runner to pick up a job. Jobs waiting for runners are in the pending state.',
      )
    "
    :wait-times="waitTimes"
    :wait-times-loading="waitTimesLoading"
    :wait-time-history-empty-state-description="
      s__('Runners|No jobs have been run by instance runners in the past 3 hours.')
    "
    :wait-time-history-enabled="isHistoryFeatureEnabled"
    :wait-time-history="waitTimeHistory"
    :wait-time-history-loading="waitTimeHistoryLoading"
  />
</template>
