import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash-es';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import GroupRunnersActiveList from 'ee/ci/runner/group_runners_dashboard/group_runners_active_list.vue';
import groupMostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/group_most_active_runners.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { captureException } from '~/sentry/sentry_browser_wrapper';

import { groupMostActiveRunnersData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

const [edge1] = groupMostActiveRunnersData.data.group.runners.edges;

Vue.use(VueApollo);

describe('GroupRunnersActiveList', () => {
  let wrapper;
  let groupMostActiveRunnersHandler;

  const findRunnersActiveList = () => wrapper.findComponent(RunnerActiveList);

  const createComponent = () => {
    wrapper = shallowMountExtended(GroupRunnersActiveList, {
      propsData: {
        groupFullPath: 'group-path',
      },
      apolloProvider: createMockApollo([
        [groupMostActiveRunnersQuery, groupMostActiveRunnersHandler],
      ]),
    });
  };

  beforeEach(() => {
    groupMostActiveRunnersHandler = jest.fn();
  });

  it('Requests most active runners', () => {
    createComponent();

    expect(groupMostActiveRunnersHandler).toHaveBeenCalledTimes(1);
  });

  describe('When loading data', () => {
    it('should show a loading skeleton', () => {
      createComponent();

      expect(findRunnersActiveList().props('loading')).toBe(true);
    });
  });

  describe('When there are active runners', () => {
    beforeEach(async () => {
      groupMostActiveRunnersHandler.mockResolvedValue(groupMostActiveRunnersData);

      createComponent();
      await waitForPromises();
    });

    it('shows results', () => {
      expect(findRunnersActiveList().props('loading')).toBe(false);
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(2);
    });

    it('shows runner url', () => {
      const { webUrl, node } = edge1;

      expect(findRunnersActiveList().props('activeRunners')[0]).toMatchObject(node);
      expect(findRunnersActiveList().props('activeRunners')[0].webUrl).toEqual(webUrl);
    });
  });

  describe('When there are active runners with no active jobs', () => {
    beforeEach(async () => {
      const resolvedValue = cloneDeep(groupMostActiveRunnersData);
      resolvedValue.data.group.runners.edges[1].node.runningJobCount = 0; // second result should ignored

      groupMostActiveRunnersHandler.mockResolvedValue(resolvedValue);

      createComponent();
      await waitForPromises();
    });

    it('ignores runners with no active jobs', () => {
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(1);
      expect(findRunnersActiveList().props('activeRunners')[0].id).toBe(edge1.node.id);
    });
  });

  describe('When an error occurs', () => {
    beforeEach(async () => {
      groupMostActiveRunnersHandler.mockRejectedValue(new Error('Error!'));

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
