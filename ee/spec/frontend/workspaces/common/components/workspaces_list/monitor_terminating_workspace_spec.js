import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import MonitorTerminatingWorkspace from 'ee/workspaces/common/components/monitor_terminating_workspace.vue';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import getWorkspaceStateQuery from 'ee/workspaces/common/graphql/queries/get_workspace_state.query.graphql';
import { GET_WORKSPACE_STATE_INTERVAL, WORKSPACE_STATES } from 'ee/workspaces/common/constants';
import { GET_WORKSPACE_STATE_QUERY_RESULT } from '../../../mock_data';

Vue.use(VueApollo);
describe('workspaces/common/components/workspaces_list/monitor_terminating_workspace.vue', () => {
  // eslint-disable-next-line no-unused-vars
  let wrapper;
  let mockApollo;

  const $toast = {
    show: jest.fn(),
  };

  const createComponent = (
    options = {
      getWorkspaceStateQueryHandler: jest.fn().mockResolvedValue(GET_WORKSPACE_STATE_QUERY_RESULT),
    },
  ) => {
    mockApollo = createMockApollo([
      [getWorkspaceStateQuery, options.getWorkspaceStateQueryHandler],
    ]);

    wrapper = shallowMount(MonitorTerminatingWorkspace, {
      apolloProvider: mockApollo,
      propsData: {
        workspaceId: '1',
      },
      mocks: {
        $toast,
      },
    });
  };

  describe('terminated workspace', () => {
    const mockTerminatedWorkspaceStateResult = {
      data: {
        workspace: {
          ...GET_WORKSPACE_STATE_QUERY_RESULT.data.workspace,
          actualState: WORKSPACE_STATES.terminated,
        },
      },
    };

    const advanceToNextFetch = () => {
      jest.advanceTimersByTime(GET_WORKSPACE_STATE_INTERVAL);
    };

    beforeEach(async () => {
      createComponent({
        getWorkspaceStateQueryHandler: jest
          .fn()
          .mockResolvedValueOnce(GET_WORKSPACE_STATE_QUERY_RESULT)
          .mockResolvedValue(mockTerminatedWorkspaceStateResult),
      });
      await waitForPromises();
    });

    afterEach(() => {
      mockApollo = null;
    });

    it('does not show toast when no workspace terminated', () => {
      expect($toast.show).toHaveBeenCalledTimes(0);
    });

    it('shows toast when workspace is successfully terminated', async () => {
      await advanceToNextFetch();
      await waitForPromises();

      expect($toast.show).toHaveBeenCalledTimes(1);
      expect($toast.show).toHaveBeenCalledWith(
        `${mockTerminatedWorkspaceStateResult.data.workspace.name} has been terminated.`,
      );
    });
  });
});
