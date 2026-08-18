import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { TEST_HOST } from 'spec/test_constants';
import MergeTrainsApp from 'ee/ci/merge_trains/merge_trains_app.vue';
import MergeTrainBranchSelector from 'ee/ci/merge_trains/components/merge_train_branch_selector.vue';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';
import getActiveMergeTrainsQuery from 'ee/ci/merge_trains/graphql/queries/get_active_merge_trains.query.graphql';
import getCompletedMergeTrainsQuery from 'ee/ci/merge_trains/graphql/queries/get_completed_merge_trains.query.graphql';
import deleteCarMutation from 'ee/ci/merge_trains/graphql/mutations/delete_car.mutation.graphql';
import { POLL_INTERVAL } from 'ee/ci/merge_trains/constants';
import * as urlUtils from '~/lib/utils/url_utility';
import {
  activeTrain,
  mergedTrain,
  emptyTrain,
  deleteCarSuccess,
  deleteCarFailure,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('MergeTrainsApp', () => {
  let wrapper;

  const activeTrainsHandler = jest.fn().mockResolvedValue(activeTrain);
  const mergedTrainsHandler = jest.fn().mockResolvedValue(mergedTrain);
  const emptyTrainsHandler = jest.fn().mockResolvedValue(emptyTrain);
  const deleteCarHandler = jest.fn().mockResolvedValue(deleteCarSuccess);
  const deleteCarFailureHandler = jest.fn().mockResolvedValue(deleteCarFailure);
  const errorHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const carId = 'gid://gitlab/MergeTrains::Car/66';

  const defaultHandlers = [
    [getActiveMergeTrainsQuery, activeTrainsHandler],
    [getCompletedMergeTrainsQuery, mergedTrainsHandler],
    [deleteCarMutation, deleteCarHandler],
  ];

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = (handlers = defaultHandlers) => {
    wrapper = shallowMountExtended(MergeTrainsApp, {
      provide: {
        fullPath: 'namespace/project',
        defaultBranch: 'master',
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  const advanceToNextFetch = () => {
    jest.advanceTimersByTime(POLL_INTERVAL);
  };

  const findBranchSelector = () => wrapper.findComponent(MergeTrainBranchSelector);
  const findTabs = () => wrapper.findComponent(MergeTrainTabs);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findActiveEmptyState = () => wrapper.findByTestId('active-empty-state');
  const findMergedEmptyState = () => wrapper.findByTestId('merged-empty-state');
  const findActiveTable = () => wrapper.findComponentByTestId('active-merge-trains-table');
  const findCompletedTable = () => wrapper.findByTestId('completed-merge-trains-table');

  describe('loading', () => {
    it('shows loading icon', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTabs().exists()).toBe(false);
      expect(findActiveTable().exists()).toBe(false);
      expect(findCompletedTable().exists()).toBe(false);
      expect(findBranchSelector().exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    it('displays empty state', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, activeTrainsHandler],
        [getCompletedMergeTrainsQuery, emptyTrainsHandler],
      ]);

      await waitForPromises();

      expect(findMergedEmptyState().exists()).toBe(true);
      expect(findActiveEmptyState().exists()).toBe(false);
      expect(findActiveTable().exists()).toBe(true);
      expect(findCompletedTable().exists()).toBe(false);
    });
  });

  describe('defaults', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders merge train tabs', () => {
      expect(findTabs().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the merge trains tables', () => {
      expect(findActiveEmptyState().exists()).toBe(false);
      expect(findMergedEmptyState().exists()).toBe(false);
      expect(findActiveTable().exists()).toBe(true);
      expect(findCompletedTable().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the merge train branch filter', () => {
      expect(findBranchSelector().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('calls queries with correct variables', () => {
      const expectedVariables = {
        fullPath: 'namespace/project',
        targetBranch: 'master',
        after: null,
        before: null,
        first: 20,
        last: null,
      };

      expect(activeTrainsHandler).toHaveBeenCalledWith({
        status: 'ACTIVE',
        ...expectedVariables,
      });
      expect(mergedTrainsHandler).toHaveBeenCalledWith({
        activityStatus: 'COMPLETED',
        ...expectedVariables,
      });
    });
  });

  describe('events', () => {
    it('refetches queries on the branch-changed event and sets branch query param', async () => {
      createComponent();

      jest.spyOn(urlUtils, 'updateHistory');

      const targetBranch = 'feature-branch';

      await waitForPromises();

      findBranchSelector().vm.$emit('branch-changed', targetBranch);

      await waitForPromises();

      const expectedVariables = {
        fullPath: 'namespace/project',
        targetBranch,
        after: null,
        before: null,
        first: 20,
        last: null,
      };

      expect(activeTrainsHandler).toHaveBeenCalledWith({
        status: 'ACTIVE',
        ...expectedVariables,
      });
      expect(mergedTrainsHandler).toHaveBeenCalledWith({
        activityStatus: 'COMPLETED',
        ...expectedVariables,
      });
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?branch=${targetBranch}`,
      });
    });

    it('refetches query on page-change event', async () => {
      createComponent();

      await waitForPromises();

      const paginationInfo = {
        first: 20,
        after: 'eyJpZCI6IjUzIn0',
        last: null,
        before: null,
      };

      findActiveTable().vm.$emit('page-change', paginationInfo);

      await waitForPromises();

      expect(activeTrainsHandler).toHaveBeenCalledWith({
        fullPath: 'namespace/project',
        targetBranch: 'master',
        status: 'ACTIVE',
        ...paginationInfo,
      });
    });

    it.each`
      branchValue     | expectedBranch
      ${'dev-branch'} | ${'dev-branch'}
      ${null}         | ${'master'}
    `(
      'expects $expectedBranch when branch query param is $branchValue',
      async ({ branchValue, expectedBranch }) => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(branchValue);

        createComponent();

        await waitForPromises();

        const expectedVariables = {
          fullPath: 'namespace/project',
          targetBranch: expectedBranch,
          after: null,
          before: null,
          first: 20,
          last: null,
        };

        expect(activeTrainsHandler).toHaveBeenCalledWith({
          status: 'ACTIVE',
          ...expectedVariables,
        });
        expect(mergedTrainsHandler).toHaveBeenCalledWith({
          activityStatus: 'COMPLETED',
          ...expectedVariables,
        });
      },
    );
  });

  describe('query errors', () => {
    it('shows query error for completed merge trains', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, activeTrainsHandler],
        [getCompletedMergeTrainsQuery, errorHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while trying to fetch the completed merge train.',
      });
    });

    it('shows query error for active merge trains', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, errorHandler],
        [getCompletedMergeTrainsQuery, mergedTrainsHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while trying to fetch the active merge train.',
      });
    });
  });

  describe('polling', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('polls data only for the active tab', async () => {
      findTabs().vm.$emit('active-tab', 0);

      expect(activeTrainsHandler).toHaveBeenCalledTimes(1);
      expect(mergedTrainsHandler).toHaveBeenCalledTimes(1);

      advanceToNextFetch();
      await waitForPromises();

      expect(activeTrainsHandler).toHaveBeenCalledTimes(2);
      expect(mergedTrainsHandler).toHaveBeenCalledTimes(1);

      advanceToNextFetch();

      expect(activeTrainsHandler).toHaveBeenCalledTimes(3);
      expect(mergedTrainsHandler).toHaveBeenCalledTimes(1);

      findTabs().vm.$emit('active-tab', 1);

      advanceToNextFetch();

      expect(activeTrainsHandler).toHaveBeenCalledTimes(3);
      expect(mergedTrainsHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('delete merge train car', () => {
    it('calls mutation with carId', async () => {
      createComponent();

      await waitForPromises();

      expect(activeTrainsHandler).toHaveBeenCalledTimes(1);

      findActiveTable().vm.$emit('delete-car', carId);

      expect(deleteCarHandler).toHaveBeenCalledWith({ input: { carId } });
      expect(activeTrainsHandler).toHaveBeenCalledTimes(2);
    });

    it('shows mutation error for delete car failure', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, activeTrainsHandler],
        [getCompletedMergeTrainsQuery, mergedTrainsHandler],
        [deleteCarMutation, deleteCarFailureHandler],
      ]);

      await waitForPromises();

      findActiveTable().vm.$emit('delete-car', carId);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'New error',
      });
    });
  });
});
