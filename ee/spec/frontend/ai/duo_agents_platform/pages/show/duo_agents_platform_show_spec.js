import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import DuoAgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import AgentFlowCancelationModal from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_cancelation_modal.vue';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from 'ee/ai/duo_agents_platform/constants';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';
import { clearRouteState } from 'ee/ai/duo_agents_platform/utils/navigation_state';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { cancelWorkflow } from 'ee/rest_api';
import * as aiGraphql from 'ee/ai/graphql';

import { mockGetAgentFlowResponse, mockDuoMessages, mockUser1 } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('ee/rest_api');
jest.mock('ee/ai/duo_agents_platform/utils/navigation_state', () => ({
  ...jest.requireActual('ee/ai/duo_agents_platform/utils/navigation_state'),
  clearRouteState: jest.fn(),
}));

describe('DuoAgentsPlatformShow', () => {
  let wrapper;
  let getAgentFlowHandler;

  const agentFlowId = '1';
  const graphqlWorkflowId = convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, agentFlowId);
  const defaultMockRoute = {
    params: {
      id: agentFlowId,
    },
  };

  const createWrapper = (props = {}, mockRoute = defaultMockRoute, provide = {}) => {
    const handlers = [[getAgentFlow, getAgentFlowHandler]];

    wrapper = shallowMount(DuoAgentsPlatformShow, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...props,
      },
      mocks: {
        $route: mockRoute,
      },
      provide: {
        ...provide,
      },
    });

    return waitForPromises();
  };

  const findAgentFlowDetails = () => wrapper.findComponent(AgentFlowDetails);
  const findCancelConfirmationModal = () => wrapper.findComponent(AgentFlowCancelationModal);

  beforeEach(() => {
    getAgentFlowHandler = jest.fn().mockResolvedValue(mockGetAgentFlowResponse);
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the AgentFlowDetails component', () => {
      expect(findAgentFlowDetails().exists()).toBe(true);
    });

    it('passes correct props to AgentFlowDetails', () => {
      const workflowDetailsProps = findAgentFlowDetails().props();

      // Use toMatchObject instead of toEqual because Vue 3 passes through the :class binding
      // as a 'class' prop, while Vue 2 does not include it in component props
      expect(workflowDetailsProps).toMatchObject({
        isLoading: false,
        status: 'RUNNING',
        humanStatus: 'Running',
        title: '',
        allExecutorUrls: ['https://gitlab.com/gitlab-org/gitlab/-/jobs/456'],
        createdAt: expect.any(String),
        updatedAt: expect.any(String),
        agentFlowDefinition: 'Software development',
        modelName: 'claude_sonnet_4_6',
        modelIdentifier: 'claude-sonnet-4-20250514',
        duoMessages: mockDuoMessages,
        project: mockGetAgentFlowResponse.data.duoWorkflowWorkflows.edges[0].node.project,
        canUpdateWorkflow: true,
        user: mockUser1,
        summary: '',
        workItem: null,
        mergeRequest: null,
      });
    });
  });

  describe('Apollo queries', () => {
    describe('agentFlowEvents query', () => {
      describe('when loading', () => {
        beforeEach(() => {
          // Not awaiting here simulates the loading state
          createWrapper();
        });

        it('passes the loading state to the details component', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(true);
        });
      });

      describe('on successful response', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        it('fetches workflow events data with correct variables', () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);
          expect(getAgentFlowHandler).toHaveBeenCalledWith({
            workflowId: graphqlWorkflowId,
          });
        });

        it('does not show an error', () => {
          expect(createAlert).not.toHaveBeenCalled();
        });

        it('passes the loading state to the details component as false', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(false);
        });
      });

      describe('when agentFlowEvents query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: errorMessage, captureError: true });
        });
      });

      describe('when error occurs without message', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(''));
          await createWrapper();
        });

        it('calls createAlert with default error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while fetching Agent Flows',
            captureError: true,
          });
        });
      });

      describe('polling', () => {
        beforeEach(async () => {
          jest.useFakeTimers();
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        afterEach(() => {
          jest.useRealTimers();
        });

        it('polls after 10 seconds', async () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(3000);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(2);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(3);
        });

        it.each(['FINISHED', 'STOPPED', 'FAILED'])(
          'stops polling once the workflow status reaches %s',
          async (status) => {
            const terminalResponse = {
              data: {
                duoWorkflowWorkflows: {
                  edges: [
                    {
                      node: {
                        ...mockGetAgentFlowResponse.data.duoWorkflowWorkflows.edges[0].node,
                        status,
                      },
                    },
                  ],
                },
              },
            };
            getAgentFlowHandler.mockResolvedValueOnce(terminalResponse);

            jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
            await waitForPromises();

            // Subsequent intervals should not trigger more requests.
            jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL * 5);
            await waitForPromises();

            expect(getAgentFlowHandler).toHaveBeenCalledTimes(2);
          },
        );
      });

      describe('when query errors', () => {
        let stopPollingSpy;

        const buildGraphQLError = (code) => {
          const err = new Error('some error');
          err.graphQLErrors = [{ extensions: { code } }];
          return err;
        };

        const mountWithError = async (err, provide = {}) => {
          getAgentFlowHandler.mockRejectedValue(err);
          const mountPromise = createWrapper({}, defaultMockRoute, provide);
          stopPollingSpy = jest.spyOn(wrapper.vm.$apollo.queries.agentFlow, 'stopPolling');
          await mountPromise;
        };

        beforeEach(() => {
          clearRouteState.mockClear();
        });

        it.each([
          'INSUFFICIENT_NAMESPACE_PERMISSIONS',
          'NO_DEFAULT_NAMESPACE',
          'WORKFLOW_NOT_FOUND',
          'NO_RESOURCE_PERMISSIONS',
        ])('stops polling and clears the saved side-panel route on %s', async (code) => {
          await mountWithError(buildGraphQLError(code), { isSidePanelView: true });

          expect(stopPollingSpy).toHaveBeenCalled();
          expect(clearRouteState).toHaveBeenCalledWith('duo_agents_platform_last_route_side_panel');
        });

        it('keeps polling on transient errors so the view recovers when the network does', async () => {
          await mountWithError(new Error('Network error'));

          expect(stopPollingSpy).not.toHaveBeenCalled();
          expect(clearRouteState).not.toHaveBeenCalled();
        });

        it('does not stop polling or clear the saved route for unrelated error codes', async () => {
          await mountWithError(buildGraphQLError('SOME_OTHER_CODE'), { isSidePanelView: true });

          expect(stopPollingSpy).not.toHaveBeenCalled();
          expect(clearRouteState).not.toHaveBeenCalled();
        });

        it('stops polling but does not clear the saved route outside the side panel view', async () => {
          await mountWithError(buildGraphQLError('INSUFFICIENT_NAMESPACE_PERMISSIONS'), {
            isSidePanelView: false,
          });

          expect(stopPollingSpy).toHaveBeenCalled();
          expect(clearRouteState).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('panel header state lifecycle', () => {
    it('updates the panel title, subtitle, and session status when the query resolves in the side panel', async () => {
      const setTitle = jest.spyOn(aiGraphql, 'setPanelTitle');
      const setSubtitle = jest.spyOn(aiGraphql, 'setPanelSubtitle');
      const setStatus = jest.spyOn(aiGraphql, 'setAgentSessionStatus');

      await createWrapper({}, defaultMockRoute, { isSidePanelView: true });

      expect(setTitle).toHaveBeenCalledWith('Test Project');
      expect(setSubtitle).toHaveBeenCalledWith(`Software development #${agentFlowId}`);
      expect(setStatus).toHaveBeenCalledWith('RUNNING');
    });

    it('clears the panel title, subtitle, and session status on unmount in the side panel', async () => {
      const setTitle = jest.spyOn(aiGraphql, 'setPanelTitle');
      const setSubtitle = jest.spyOn(aiGraphql, 'setPanelSubtitle');
      const setStatus = jest.spyOn(aiGraphql, 'setAgentSessionStatus');

      await createWrapper({}, defaultMockRoute, { isSidePanelView: true });

      setTitle.mockClear();
      setSubtitle.mockClear();
      setStatus.mockClear();

      wrapper.destroy();

      expect(setTitle).toHaveBeenCalledWith(null);
      expect(setSubtitle).toHaveBeenCalledWith(null);
      expect(setStatus).toHaveBeenCalledWith(null);
    });

    it('does not clear the panel state on unmount outside the side panel', async () => {
      const setTitle = jest.spyOn(aiGraphql, 'setPanelTitle');
      const setSubtitle = jest.spyOn(aiGraphql, 'setPanelSubtitle');
      const setStatus = jest.spyOn(aiGraphql, 'setAgentSessionStatus');

      await createWrapper();

      setTitle.mockClear();
      setSubtitle.mockClear();
      setStatus.mockClear();

      wrapper.destroy();

      expect(setTitle).not.toHaveBeenCalled();
      expect(setSubtitle).not.toHaveBeenCalled();
      expect(setStatus).not.toHaveBeenCalled();
    });
  });

  describe('route parameter handling', () => {
    it('converts route id to GraphQL ID correctly', async () => {
      const customWorkflowId = '123';

      wrapper = createWrapper(
        {},
        {
          params: {
            id: customWorkflowId,
          },
        },
      );

      await waitForPromises();

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, customWorkflowId),
      });
    });
  });

  describe('Cancel session functionality', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('confirmation modal', () => {
      it('renders the cancel session confirmation modal', () => {
        expect(findCancelConfirmationModal().exists()).toBe(true);
        expect(findCancelConfirmationModal().props('visible')).toBe(false);
        expect(findCancelConfirmationModal().props('loading')).toBe(false);
      });

      it('shows modal when cancel-session event is emitted from AgentFlowDetails', async () => {
        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);
      });

      it('hides modal when hide event is emitted', async () => {
        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);

        findCancelConfirmationModal().vm.$emit('hide');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(false);
      });
    });

    describe('session cancellation', () => {
      beforeEach(async () => {
        await createWrapper();
      });

      it('calls cancelWorkflow API when confirmed', async () => {
        cancelWorkflow.mockResolvedValue({});

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(cancelWorkflow).toHaveBeenCalledWith(agentFlowId);
        expect(findCancelConfirmationModal().props('visible')).toBe(false);
      });

      it('shows success alert on successful cancellation', async () => {
        cancelWorkflow.mockResolvedValue({});

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Session has been cancelled successfully.',
          variant: 'success',
        });
      });

      it('shows error alert on API failure', async () => {
        const errorMessage = 'Failed to cancel';
        cancelWorkflow.mockRejectedValue({
          response: {
            status: 422,
            data: { message: errorMessage },
          },
        });

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: errorMessage,
          captureError: true,
          variant: 'danger',
        });
      });

      it('shows loading state during cancellation', async () => {
        let resolveRequest;
        cancelWorkflow.mockImplementation(
          () =>
            new Promise((resolve) => {
              resolveRequest = resolve;
            }),
        );

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        findCancelConfirmationModal().vm.$emit('confirm');
        await nextTick();

        expect(findCancelConfirmationModal().props('loading')).toBe(true);

        // Resolve the promise to clean up
        resolveRequest({});
        await waitForPromises();
      });
    });
  });
});
