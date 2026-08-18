import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import AdminRunnersActiveList from 'ee/ci/runner/admin_runners_dashboard/admin_runners_active_list.vue';
import mostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/most_active_runners.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { captureException } from '~/sentry/sentry_browser_wrapper';

import { mostActiveRunnersData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

const mostActiveRunners = mostActiveRunnersData.data.runners.nodes;
const [mockRunner, mockRunner2] = mostActiveRunners;

Vue.use(VueApollo);

describe('AdminRunnersActiveList', () => {
  let wrapper;
  let mostActiveRunnersHandler;

  const findRunnersActiveList = () => wrapper.findComponent(RunnerActiveList);

  const createComponent = () => {
    wrapper = shallowMountExtended(AdminRunnersActiveList, {
      apolloProvider: createMockApollo([[mostActiveRunnersQuery, mostActiveRunnersHandler]]),
    });
  };

  beforeEach(() => {
    mostActiveRunnersHandler = jest.fn();
  });

  it('Requests most active runners', () => {
    createComponent();

    expect(mostActiveRunnersHandler).toHaveBeenCalledTimes(1);
  });

  describe('When loading data', () => {
    it('should show a loading skeleton', () => {
      createComponent();

      expect(findRunnersActiveList().props('loading')).toBe(true);
    });
  });

  describe('When there are active runners', () => {
    beforeEach(async () => {
      mostActiveRunnersHandler.mockResolvedValue(mostActiveRunnersData);

      createComponent();
      await waitForPromises();
    });

    it('shows results', () => {
      expect(findRunnersActiveList().props('loading')).toBe(false);
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(2);
    });

    it('shows runner jobs url', () => {
      const { adminUrl, ...runner } = mockRunner;
      expect(findRunnersActiveList().props('activeRunners')[0]).toMatchObject(runner);
      expect(findRunnersActiveList().props('activeRunners')[0].webUrl).toEqual(adminUrl);
    });
  });

  describe('When there are active runners with no active jobs', () => {
    beforeEach(async () => {
      mostActiveRunnersHandler.mockResolvedValue({
        data: {
          runners: {
            nodes: [
              mockRunner,
              {
                ...mockRunner2,
                runningJobCount: 0,
              },
            ],
          },
        },
      });

      createComponent();
      await waitForPromises();
    });

    it('ignores runners with no active jobs', () => {
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(1);
      expect(findRunnersActiveList().props('activeRunners')[0].id).toBe(mockRunner.id);
    });
  });

  describe('When an error occurs', () => {
    beforeEach(async () => {
      mostActiveRunnersHandler.mockRejectedValue(new Error('Error!'));

      createComponent();
      await waitForPromises();
    });

    it('shows an error', () => {
      expect(createAlert).toHaveBeenCalled();
    });

    it('reports an error', () => {
      expect(captureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });
});
