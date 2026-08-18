import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import GroupRunnersWaitTimes from 'ee/ci/runner/group_runners_dashboard/group_runners_wait_times.vue';

import RunnerWaitTimes from 'ee/ci/runner/components/runner_wait_times.vue';
import groupRunnerWaitTimesQuery from 'ee/ci/runner/graphql/performance/group_runner_wait_times.query.graphql';
import groupRunnerWaitTimeHistoryQuery from 'ee/ci/runner/graphql/performance/group_runner_wait_time_history.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { queuedDuration, timeSeries } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const mockGroupPath = '/group/-/runners';

const groupRunnersWaitTimes = {
  data: {
    group: {
      id: 'group1',
      runners: {
        jobsStatistics: {
          queuedDuration,
          __typename: 'CiJobsStatistics',
        },
        __typename: 'CiRunnerConnection',
      },
      __typename: 'Group',
    },
  },
};

const groupRunnersWaitTimeHistory = {
  data: {
    group: {
      id: 'group1',
      ciQueueingHistory: {
        timeSeries,
      },
      __typename: 'Group',
    },
  },
};

describe('RunnerActiveList', () => {
  let wrapper;
  let groupRunnerWaitTimesHandler;
  let groupRunnerWaitTimeHistoryHandler;

  const findRunnerWaitTimes = () => wrapper.findComponent(RunnerWaitTimes);

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(GroupRunnersWaitTimes, {
      apolloProvider: createMockApollo([
        [groupRunnerWaitTimesQuery, groupRunnerWaitTimesHandler],
        [groupRunnerWaitTimeHistoryQuery, groupRunnerWaitTimeHistoryHandler],
      ]),
      propsData: {
        groupFullPath: mockGroupPath,
      },
      provide: { clickhouseCiAnalyticsAvailable: true },
      ...options,
    });
  };

  beforeEach(() => {
    groupRunnerWaitTimesHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
    groupRunnerWaitTimeHistoryHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
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
      expect(groupRunnerWaitTimesHandler).toHaveBeenCalledTimes(1);
    });

    it('requests wait time history', () => {
      expect(groupRunnerWaitTimeHistoryHandler).toHaveBeenCalledTimes(1);
      expect(groupRunnerWaitTimeHistoryHandler).toHaveBeenCalledWith({
        fromTime: expect.any(String),
        toTime: expect.any(String),
        fullPath: mockGroupPath,
      });
    });
  });

  describe('When wait times are loaded', () => {
    beforeEach(async () => {
      groupRunnerWaitTimesHandler.mockResolvedValue(groupRunnersWaitTimes);
      groupRunnerWaitTimeHistoryHandler.mockResolvedValue(groupRunnersWaitTimeHistory);

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
      groupRunnerWaitTimesHandler.mockResolvedValue(groupRunnersWaitTimes);

      createComponent({ provide: { clickhouseCiAnalyticsAvailable: false } });
      await waitForPromises();
    });

    it('request wait times', () => {
      expect(groupRunnerWaitTimesHandler).toHaveBeenCalledTimes(1);
    });

    it('does not request wait time history', () => {
      expect(groupRunnerWaitTimeHistoryHandler).toHaveBeenCalledTimes(0);
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
