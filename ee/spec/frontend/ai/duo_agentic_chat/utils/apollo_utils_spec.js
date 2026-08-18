import createMockApollo from 'helpers/mock_apollo_helper';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import deleteAgenticWorkflowMutation from 'ee/ai/graphql/delete_agentic_workflow.mutation.graphql';
import updateWebSearchMutation from 'ee/ai/graphql/update_duo_workflow_web_search.mutation.graphql';
import getWorkflowLatestCheckpointQuery from 'ee/ai/graphql/get_workflow_latest_checkpoint.query.graphql';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import {
  ApolloUtils,
  getCatalogAgentsQuery,
  getFoundationalAgentsQuery,
  fetchMoreConfiguredAgents,
  CONFIGURED_AGENTS_PER_PAGE,
} from 'ee/ai/duo_agentic_chat/utils/apollo_utils';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_NEW_CHAT_DEFINITION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
} from 'ee/ai/constants';
import { MULTI_THREADED_CONVERSATION_TYPE } from 'ee/ai/tanuki_bot/constants';
import {
  MOCK_PROJECT_ID,
  MOCK_NAMESPACE_ID,
  MOCK_WORKFLOW_ID,
  MOCK_GOAL,
  MOCK_ACTIVE_THREAD,
  MOCK_WORKFLOW_MUTATION_RESPONSE,
  MOCK_DELETE_WORKFLOW_RESPONSE,
  MOCK_FETCH_WORKFLOW_LATEST_CHECKPOINT_RESPONSE,
  MOCK_AGENT_FLOW_CONFIG_RESPONSE,
  MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
} from './mock_data';

describe('ApolloUtils', () => {
  let apolloProvider;
  let duoWorkflowMutationHandlerMock;
  let deleteWorkflowMutationHandlerMock;
  let updateWebSearchMutationHandlerMock;
  let getWorkflowLatestCheckpointQueryHandlerMock;

  const MOCK_UPDATE_WEB_SEARCH_RESPONSE = {
    data: {
      updateDuoWorkflowWebSearch: {
        workflow: { id: MOCK_WORKFLOW_ID },
        errors: [],
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();

    duoWorkflowMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_WORKFLOW_MUTATION_RESPONSE);
    deleteWorkflowMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_DELETE_WORKFLOW_RESPONSE);
    updateWebSearchMutationHandlerMock = jest
      .fn()
      .mockResolvedValue(MOCK_UPDATE_WEB_SEARCH_RESPONSE);
    getWorkflowLatestCheckpointQueryHandlerMock = jest
      .fn()
      .mockResolvedValue(MOCK_FETCH_WORKFLOW_LATEST_CHECKPOINT_RESPONSE);

    apolloProvider = createMockApollo([
      [duoWorkflowMutation, duoWorkflowMutationHandlerMock],
      [deleteAgenticWorkflowMutation, deleteWorkflowMutationHandlerMock],
      [updateWebSearchMutation, updateWebSearchMutationHandlerMock],
      [getWorkflowLatestCheckpointQuery, getWorkflowLatestCheckpointQueryHandlerMock],
    ]);
  });

  describe('createWorkflow', () => {
    it.each`
      description                            | projectId          | namespaceId          | workflowDefinition
      ${'projectId only'}                    | ${MOCK_PROJECT_ID} | ${undefined}         | ${undefined}
      ${'namespaceId only'}                  | ${undefined}       | ${MOCK_NAMESPACE_ID} | ${undefined}
      ${'both projectId and namespaceId'}    | ${MOCK_PROJECT_ID} | ${MOCK_NAMESPACE_ID} | ${undefined}
      ${'neither projectId nor namespaceId'} | ${undefined}       | ${undefined}         | ${undefined}
      ${'with workflow definition'}          | ${undefined}       | ${undefined}         | ${'some_agent/v1'}
    `(
      'creates workflow with $description',
      async ({ projectId, namespaceId, workflowDefinition }) => {
        const params = {
          goal: MOCK_GOAL,
          aiCatalogItemVersionId: 5,
        };

        if (projectId) params.projectId = projectId;
        if (namespaceId) params.namespaceId = namespaceId;
        if (workflowDefinition) params.workflowDefinition = workflowDefinition;

        await ApolloUtils.createWorkflow(apolloProvider.defaultClient, params);

        const expectedCallVariables = {
          goal: MOCK_GOAL,
          workflowDefinition: workflowDefinition || DUO_WORKFLOW_CHAT_DEFINITION,
          agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
          preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
          conversationType: MULTI_THREADED_CONVERSATION_TYPE,
          aiCatalogItemVersionId: 5,
        };

        if (projectId) expectedCallVariables.projectId = projectId;
        if (namespaceId) expectedCallVariables.namespaceId = namespaceId;

        expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith(expectedCallVariables);
      },
    );

    it.each([true, false])('always sends webSearchEnabled: %s', async (webSearchEnabled) => {
      await ApolloUtils.createWorkflow(apolloProvider.defaultClient, {
        goal: MOCK_GOAL,
        webSearchEnabled,
      });

      expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith(
        expect.objectContaining({ webSearchEnabled }),
      );
    });

    describe('when no workflowDefinition is provided', () => {
      it.each`
        flag     | expectedDefinition
        ${true}  | ${DUO_WORKFLOW_NEW_CHAT_DEFINITION}
        ${false} | ${DUO_WORKFLOW_CHAT_DEFINITION}
      `(
        'uses $expectedDefinition when agenticChatFlowRegistryMigration is $flag',
        async ({ flag, expectedDefinition }) => {
          await ApolloUtils.createWorkflow(apolloProvider.defaultClient, {
            goal: MOCK_GOAL,
            agenticChatFlowRegistryMigration: flag,
          });

          expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith(
            expect.objectContaining({ workflowDefinition: expectedDefinition }),
          );
        },
      );
    });

    describe('error handling', () => {
      it.each`
        description             | errors                               | shouldThrow | expectedError
        ${'multiple errors'}    | ${['Error 1', 'Error 2', 'Error 3']} | ${true}     | ${'Error 1, Error 2, Error 3'}
        ${'single error'}       | ${['Single error message']}          | ${true}     | ${'Single error message'}
        ${'empty errors array'} | ${[]}                                | ${false}    | ${null}
        ${'null errors'}        | ${null}                              | ${false}    | ${null}
      `('handles $description correctly', async ({ errors, shouldThrow, expectedError }) => {
        const response = {
          data: {
            aiDuoWorkflowCreate: {
              errors,
              workflow: {
                id: MOCK_WORKFLOW_ID,
                threadId: MOCK_ACTIVE_THREAD,
              },
            },
          },
        };

        duoWorkflowMutationHandlerMock.mockResolvedValue(response);

        const promise = ApolloUtils.createWorkflow(apolloProvider.defaultClient, {
          goal: MOCK_GOAL,
          activeThread: MOCK_ACTIVE_THREAD,
          projectId: MOCK_PROJECT_ID,
        });

        if (shouldThrow) {
          await expect(promise).rejects.toThrow(expectedError);
        } else {
          await expect(promise).resolves.not.toThrow();
        }
      });
    });
  });

  describe('updateWebSearch', () => {
    it.each([true, false])('persists webSearchEnabled: %s', async (webSearchEnabled) => {
      await ApolloUtils.updateWebSearch(apolloProvider.defaultClient, {
        workflowId: MOCK_WORKFLOW_ID,
        webSearchEnabled,
      });

      expect(updateWebSearchMutationHandlerMock).toHaveBeenCalledWith({
        workflowId: MOCK_WORKFLOW_ID,
        webSearchEnabled,
      });
    });

    it('throws the joined errors when the mutation returns errors', async () => {
      updateWebSearchMutationHandlerMock.mockResolvedValue({
        data: {
          updateDuoWorkflowWebSearch: {
            workflow: null,
            errors: ['Workflow not found', 'Nope'],
          },
        },
      });

      await expect(
        ApolloUtils.updateWebSearch(apolloProvider.defaultClient, {
          workflowId: MOCK_WORKFLOW_ID,
          webSearchEnabled: true,
        }),
      ).rejects.toThrow('Workflow not found, Nope');
    });
  });

  describe('deleteWorkflow', () => {
    const mockWorkflowId = '123';

    it('successfully deletes workflow', async () => {
      deleteWorkflowMutationHandlerMock.mockResolvedValue(MOCK_DELETE_WORKFLOW_RESPONSE);

      await ApolloUtils.deleteWorkflow(apolloProvider.defaultClient, mockWorkflowId);

      expect(deleteWorkflowMutationHandlerMock).toHaveBeenCalledWith({
        input: {
          workflowId: mockWorkflowId,
        },
      });
    });

    describe('error handling', () => {
      it.each`
        description             | errors                      | shouldThrow | expectedError
        ${'multiple errors'}    | ${['Error 1', 'Error 2']}   | ${true}     | ${'Error 1, Error 2'}
        ${'single error'}       | ${['Single error message']} | ${true}     | ${'Single error message'}
        ${'empty errors array'} | ${[]}                       | ${false}    | ${null}
        ${'null errors'}        | ${null}                     | ${false}    | ${null}
      `('handles $description correctly', async ({ errors, shouldThrow, expectedError }) => {
        deleteWorkflowMutationHandlerMock.mockResolvedValue({
          data: {
            deleteDuoWorkflowsWorkflow: {
              success: !shouldThrow,
              clientMutationId: null,
              errors,
            },
          },
        });

        const promise = ApolloUtils.deleteWorkflow(apolloProvider.defaultClient, mockWorkflowId);

        if (shouldThrow) {
          await expect(promise).rejects.toThrow(expectedError);
        } else {
          await expect(promise).resolves.not.toThrow();
        }
      });
    });
  });

  describe('fetchWorkflowEvents', () => {
    const mockWorkflowId = '456';

    it('successfully fetches workflow events', async () => {
      const mockApolloClient = {
        query: jest.fn().mockResolvedValue(MOCK_FETCH_WORKFLOW_LATEST_CHECKPOINT_RESPONSE),
      };

      const result = await ApolloUtils.fetchWorkflowEvents(mockApolloClient, mockWorkflowId);

      expect(mockApolloClient.query).toHaveBeenCalledWith({
        query: getWorkflowLatestCheckpointQuery,
        variables: {
          workflowId: mockWorkflowId,
        },
        context: {
          featureCategory: 'duo_agent_platform',
        },
        fetchPolicy: 'network-only',
      });

      expect(result).toBe(MOCK_FETCH_WORKFLOW_LATEST_CHECKPOINT_RESPONSE.data);
    });
  });

  describe('getAgentFlowConfig', () => {
    const mockAgentVersionId = '456';

    it('successfully retrieves a flow config for the agent', async () => {
      const mockApolloClient = {
        query: jest.fn().mockResolvedValue(MOCK_AGENT_FLOW_CONFIG_RESPONSE),
      };

      const result = await ApolloUtils.getAgentFlowConfig(mockApolloClient, mockAgentVersionId);

      expect(mockApolloClient.query).toHaveBeenCalledWith({
        query: getAgentFlowConfig,
        context: {
          featureCategory: 'duo_agent_platform',
        },
        variables: {
          agentVersionId: mockAgentVersionId,
        },
      });

      expect(result).toBe(MOCK_AGENT_FLOW_CONFIG_RESPONSE.data.aiCatalogAgentFlowConfig);
    });
  });

  describe('getCatalogAgentsQuery', () => {
    it.each`
      description      | queryVariables
      ${'projectId'}   | ${{ projectId: MOCK_PROJECT_ID }}
      ${'namespaceId'} | ${{ namespaceId: MOCK_NAMESPACE_ID }}
    `('returns correct query config with $description', ({ queryVariables }) => {
      const queryObject = getCatalogAgentsQuery(queryVariables);

      expect(queryObject.query).toBe(getConfiguredAgents);
      expect(queryObject.variables).toEqual({
        ...queryVariables,
        first: CONFIGURED_AGENTS_PER_PAGE,
      });
    });
  });

  describe('fetchMoreConfiguredAgents', () => {
    it('does not fetch more when hasNextPage is false', () => {
      const mockQuery = { fetchMore: jest.fn() };
      const pageInfo = { hasNextPage: false, endCursor: 'cursor' };

      fetchMoreConfiguredAgents(mockQuery, pageInfo);

      expect(mockQuery.fetchMore).not.toHaveBeenCalled();
    });

    it('does not fetch more when pageInfo is null', () => {
      const mockQuery = { fetchMore: jest.fn() };

      fetchMoreConfiguredAgents(mockQuery, null);

      expect(mockQuery.fetchMore).not.toHaveBeenCalled();
    });

    it('calls fetchMore with correct variables when hasNextPage is true', () => {
      const mockQuery = { fetchMore: jest.fn().mockResolvedValue({}) };
      const pageInfo = { hasNextPage: true, endCursor: 'cursor123' };

      fetchMoreConfiguredAgents(mockQuery, pageInfo);

      expect(mockQuery.fetchMore).toHaveBeenCalledWith({
        variables: {
          first: CONFIGURED_AGENTS_PER_PAGE,
          after: 'cursor123',
        },
        updateQuery: expect.any(Function),
      });
    });

    it('merges previous and new nodes in updateQuery', () => {
      const mockQuery = { fetchMore: jest.fn().mockResolvedValue({}) };
      const pageInfo = { hasNextPage: true, endCursor: 'cursor' };

      fetchMoreConfiguredAgents(mockQuery, pageInfo);

      const { updateQuery } = mockQuery.fetchMore.mock.calls[0][0];

      const previousResult = {
        aiCatalogConfiguredItems: {
          nodes: [{ id: 'node1' }],
          pageInfo: { hasNextPage: true, endCursor: 'cursor1' },
        },
      };

      const fetchMoreResult = {
        aiCatalogConfiguredItems: {
          nodes: [{ id: 'node2' }],
          pageInfo: { hasNextPage: false, endCursor: 'cursor2' },
        },
      };

      const merged = updateQuery(previousResult, { fetchMoreResult });

      expect(merged.aiCatalogConfiguredItems.nodes).toEqual([{ id: 'node1' }, { id: 'node2' }]);
      expect(merged.aiCatalogConfiguredItems.pageInfo).toEqual({
        hasNextPage: false,
        endCursor: 'cursor2',
      });
    });
  });

  describe('getFoundationalAgentsQuery', () => {
    const queryVariables = {
      projectId: MOCK_PROJECT_ID,
      namespaceId: MOCK_NAMESPACE_ID,
    };

    it('returns correct query config with projectId and namespaceId', () => {
      const queryObject = getFoundationalAgentsQuery(queryVariables);

      expect(queryObject.query).toBe(getFoundationalChatAgents);
      expect(queryObject.variables).toBe(queryVariables);
    });

    it('correctly returns agents and adds foundational flag', () => {
      const queryObject = getFoundationalAgentsQuery(queryVariables);
      const result = queryObject.update(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE.data);
      expect(result).toEqual([
        {
          id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
          name: 'GitLab Duo Agent',
          description: 'Duo is your general development assistant',
          referenceWithVersion: 'chat',
          flowConfig: {
            flowConfigId: 'chat',
            flowConfigSchemaVersion: null,
            flowVersion: '^1.0.0',
          },
          foundational: true,
        },
        {
          id: 'gid://gitlab/Ai::FoundationalChatAgent/agent-v1',
          name: 'Cool agent',
          description: 'An agent that makes things cooler',
          referenceWithVersion: 'agent/v1',
          flowConfig: null,
          foundational: true,
        },
      ]);
    });
  });
});
