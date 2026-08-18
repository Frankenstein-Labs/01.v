<script>
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';

import { runnerWaitTimeHistoryRange } from 'ee/ci/runner/runner_performance_utils';
import groupRunnerWaitTimesQuery from 'ee/ci/runner/graphql/performance/group_runner_wait_times.query.graphql';
import groupRunnerWaitTimeHistoryQuery from 'ee/ci/runner/graphql/performance/group_runner_wait_time_history.query.graphql';

import RunnerWaitTimes from '../components/runner_wait_times.vue';

export default {
  name: 'GroupRunnerWaitTimes',
  components: {
    RunnerWaitTimes,
  },
  inject: {
    clickhouseCiAnalyticsAvailable: {
      default: false,
    },
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
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
      query: groupRunnerWaitTimesQuery,
      update({ group }) {
        return group?.runners?.jobsStatistics?.queuedDuration;
      },
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      error(error) {
        this.handlerError(error);
      },
    },
    waitTimeHistory: {
      query: groupRunnerWaitTimeHistoryQuery,
      skip() {
        return !this.isHistoryFeatureEnabled;
      },
      variables() {
        return {
          fullPath: this.groupFullPath,
          ...runnerWaitTimeHistoryRange(),
        };
      },
      update({ group }) {
        return group?.ciQueueingHistory?.timeSeries;
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
        'Runners|The time it takes for a group runner assigned to this group to pick up a job. Jobs waiting for runners are in the pending state.',
      )
    "
    :wait-times="waitTimes"
    :wait-times-loading="waitTimesLoading"
    :wait-time-history-empty-state-description="
      s__(
        'Runners|No jobs have been run by group runners assigned to this group in the past 3 hours.',
      )
    "
    :wait-time-history-enabled="isHistoryFeatureEnabled"
    :wait-time-history="waitTimeHistory"
    :wait-time-history-loading="waitTimeHistoryLoading"
  />
</template>
