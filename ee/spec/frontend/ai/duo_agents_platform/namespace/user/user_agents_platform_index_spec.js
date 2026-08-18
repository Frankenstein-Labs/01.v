import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import UserAgentsPlatformIndex from 'ee/ai/duo_agents_platform/namespace/user/user_agents_platform_index.vue';
import getUserAgentFlows from 'ee/ai/duo_agents_platform/graphql/queries/get_user_agent_flow.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DuoAgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import { createAlert } from '~/alert';
import { mockAgentFlowEdges } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('UserAgentsPlatformIndex', () => {
  let wrapper;

  const getUserAgentFlowsHandler = jest.fn();
  const handlers = [[getUserAgentFlows, getUserAgentFlowsHandler]];

  const mockUserAgentFlowsResponse = {
    data: {
      duoWorkflowWorkflows: {
        pageInfo: {
          startCursor: 'start',
          endCursor: 'end',
          hasNextPage: true,
          hasPreviousPage: false,
        },
        edges: mockAgentFlowEdges,
      },
    },
  };

  const createWrapper = () => {
    wrapper = shallowMount(UserAgentsPlatformIndex, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        isSidePanelView: true,
      },
    });

    return waitForPromises();
  };

  const findIndexComponent = () => wrapper.findComponent(DuoAgentsPlatformIndex);

  beforeEach(() => {
    getUserAgentFlowsHandler.mockResolvedValue(mockUserAgentFlowsResponse);
  });

  it('passes correct props to DuoAgentsPlatformIndex', async () => {
    await createWrapper();

    expect(findIndexComponent().props()).toMatchObject({
      initialSort: 'UPDATED_DESC',
      hasInitialWorkflows: expect.any(Boolean),
      isLoadingWorkflows: expect.any(Boolean),
      workflows: expect.any(Array),
      workflowsPageInfo: expect.any(Object),
    });
  });

  describe('Apollo queries', () => {
    describe('workflows query', () => {
      describe('when loading', () => {
        it('passes isLoadingWorkflows as true', () => {
          // not awaiting simulates loading
          createWrapper();
          expect(findIndexComponent().props('isLoadingWorkflows')).toBe(true);
        });
      });

      describe('on successful fetch', () => {
        beforeEach(async () => {
          await createWrapper();
        });

        it('fetches workflows data with correct variables', () => {
          expect(getUserAgentFlowsHandler).toHaveBeenCalledTimes(1);
          expect(getUserAgentFlowsHandler).toHaveBeenCalledWith({
            sort: 'UPDATED_DESC',
            after: null,
            before: null,
            first: 20,
            last: null,
            type: 'non_foundational_chat_agents',
          });
        });

        it('passes workflows to DuoAgentsPlatformIndex component', () => {
          const expectedWorkflows = mockUserAgentFlowsResponse.data.duoWorkflowWorkflows.edges.map(
            (w) => w.node,
          );

          expect(findIndexComponent().props('workflows')).toEqual(expectedWorkflows);
        });

        it('passes workflowsPageInfo to DuoAgentsPlatformIndex component', () => {
          const expectedPageInfo = mockUserAgentFlowsResponse.data.duoWorkflowWorkflows.pageInfo;

          expect(findIndexComponent().props('workflowsPageInfo')).toEqual(expectedPageInfo);
        });
      });

      describe('when workflows query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          getUserAgentFlowsHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: errorMessage,
            captureError: true,
          });
        });

        it('passes empty array to DuoAgentsPlatformIndex component', () => {
          expect(findIndexComponent().props('workflows')).toEqual([]);
        });
      });

      describe('when workflows query fails without error message', () => {
        beforeEach(async () => {
          getUserAgentFlowsHandler.mockRejectedValue(new Error());
          await createWrapper();
        });

        it('calls createAlert with default error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Failed to fetch workflows',
            captureError: true,
          });
        });
      });

      describe('when workflows query returns null data', () => {
        beforeEach(async () => {
          getUserAgentFlowsHandler.mockResolvedValue({
            data: null,
          });
          await createWrapper();
        });

        it('passes empty array to DuoAgentsPlatformIndex component', () => {
          expect(findIndexComponent().props('workflows')).toEqual([]);
        });

        it('passes empty object as workflowsPageInfo', () => {
          expect(findIndexComponent().props('workflowsPageInfo')).toEqual({});
        });
      });

      describe('when workflows query returns empty edges', () => {
        beforeEach(async () => {
          getUserAgentFlowsHandler.mockResolvedValue({
            data: {
              duoWorkflowWorkflows: {
                pageInfo: {
                  startCursor: null,
                  endCursor: null,
                  hasNextPage: false,
                  hasPreviousPage: false,
                },
                edges: [],
              },
            },
          });
          await createWrapper();
        });

        it('passes empty array to DuoAgentsPlatformIndex component', () => {
          expect(findIndexComponent().props('workflows')).toEqual([]);
        });

        it('passes correct page info to DuoAgentsPlatformIndex component', () => {
          const expectedPageInfo = {
            startCursor: null,
            endCursor: null,
            hasNextPage: false,
            hasPreviousPage: false,
          };
          expect(findIndexComponent().props('workflowsPageInfo')).toEqual(expectedPageInfo);
        });
      });

      describe('when workflows query returns undefined edges', () => {
        beforeEach(async () => {
          getUserAgentFlowsHandler.mockResolvedValue({
            data: {
              duoWorkflowWorkflows: {
                pageInfo: {
                  startCursor: null,
                  endCursor: null,
                  hasNextPage: false,
                  hasPreviousPage: false,
                },
                edges: undefined,
              },
            },
          });
          await createWrapper();
        });

        it('passes empty array to DuoAgentsPlatformIndex component', () => {
          expect(findIndexComponent().props('workflows')).toEqual([]);
        });
      });
    });
  });

  describe('polling', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('polls every 10 seconds', async () => {
      expect(getUserAgentFlowsHandler).toHaveBeenCalledTimes(1);

      jest.advanceTimersByTime(5000);
      await waitForPromises();

      expect(getUserAgentFlowsHandler).toHaveBeenCalledTimes(1);

      jest.advanceTimersByTime(10000);
      await waitForPromises();

      expect(getUserAgentFlowsHandler).toHaveBeenCalledTimes(2);

      jest.advanceTimersByTime(10000);
      await waitForPromises();

      expect(getUserAgentFlowsHandler).toHaveBeenCalledTimes(3);
    });
  });
});
