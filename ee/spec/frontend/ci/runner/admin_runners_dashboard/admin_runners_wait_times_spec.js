import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AdminRunnersWaitTimes from 'ee/ci/runner/admin_runners_dashboard/admin_runners_wait_times.vue';

import RunnerWaitTimes from 'ee/ci/runner/components/runner_wait_times.vue';
import runnerWaitTimesQuery from 'ee/ci/runner/graphql/performance/runner_wait_times.query.graphql';
import runnerWaitTimeHistoryQuery from 'ee/ci/runner/graphql/performance/runner_wait_time_history.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { queuedDuration, timeSeries } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const runnersWaitTimes = {
  data: {
    runners: {
      jobsStatistics: {
        queuedDuration,
        __typename: 'CiJobsStatistics',
      },
      __typename: 'CiRunnerConnection',
    },
  },
};

const runnerWaitTimeHistory = {
  data: {
    ciQueueingHistory: {
      timeSeries,
    },
  },
};

describe('RunnerActiveList', () => {
  let wrapper;
  let runnerWaitTimesHandler;
  let runnerWaitTimeHistoryHandler;

  const findRunnerWaitTimes = () => wrapper.findComponent(RunnerWaitTimes);

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(AdminRunnersWaitTimes, {
      apolloProvider: createMockApollo([
        [runnerWaitTimesQuery, runnerWaitTimesHandler],
        [runnerWaitTimeHistoryQuery, runnerWaitTimeHistoryHandler],
      ]),
      provide: { clickhouseCiAnalyticsAvailable: true },
      ...options,
    });
  };

  beforeEach(() => {
    runnerWaitTimesHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
    runnerWaitTimeHistoryHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
  });

  describe('When loading data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows loading state', () => {
      expect(findRunnerWaitTimes().props()).toEqual({
        waitTimesPopoverDescription: expect.any(String),
        waitTimes: null,
        waitTimesLoading: true,

        waitTimeHistoryEmptyStateDescription: expect.any(String),
        waitTimeHistory: [],
        waitTimeHistoryEnabled: true,
        waitTimeHistoryLoading: true,
      });
    });

    it('requests wait times', () => {
      expect(runnerWaitTimesHandler).toHaveBeenCalledTimes(1);
    });

    it('requests wait time history', () => {
      expect(runnerWaitTimeHistoryHandler).toHaveBeenCalledTimes(1);
      expect(runnerWaitTimeHistoryHandler).toHaveBeenCalledWith({
        fromTime: expect.any(String),
        toTime: expect.any(String),
      });
    });
  });

  describe('When wait times are loaded', () => {
    beforeEach(async () => {
      runnerWaitTimesHandler.mockResolvedValue(runnersWaitTimes);
      runnerWaitTimeHistoryHandler.mockResolvedValue(runnerWaitTimeHistory);

      createComponent();
      await waitForPromises();
    });

    it('shows data', () => {
      expect(findRunnerWaitTimes().props()).toEqual({
        waitTimesPopoverDescription: expect.any(String),
        waitTimes: queuedDuration,
        waitTimesLoading: false,

        waitTimeHistoryEmptyStateDescription: expect.any(String),
        waitTimeHistory: timeSeries,
        waitTimeHistoryEnabled: true,
        waitTimeHistoryLoading: false,
      });
    });
  });

  describe('When ClickHouse is not configured', () => {
    beforeEach(async () => {
      runnerWaitTimesHandler.mockResolvedValue(runnersWaitTimes);

      createComponent({ provide: { clickhouseCiAnalyticsAvailable: false } });
      await waitForPromises();
    });

    it('request wait times', () => {
      expect(runnerWaitTimesHandler).toHaveBeenCalledTimes(1);
    });

    it('does not request wait time history', () => {
      expect(runnerWaitTimeHistoryHandler).toHaveBeenCalledTimes(0);
    });

    it('shows wait time data without history', () => {
      expect(findRunnerWaitTimes().props()).toMatchObject({
        waitTimeHistory: [],
        waitTimeHistoryEnabled: false,
        waitTimeHistoryLoading: false,
      });
    });
  });
});
