import produce from 'immer';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import deleteAgenticWorkflowMutation from 'ee/ai/graphql/delete_agentic_workflow.mutation.graphql';
import updateWebSearchMutation from 'ee/ai/graphql/update_duo_workflow_web_search.mutation.graphql';
import getWorkflowLatestCheckpointQuery from 'ee/ai/graphql/get_workflow_latest_checkpoint.query.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_NEW_CHAT_DEFINITION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
} from 'ee/ai/constants';
import { fetchPolicies } from '~/lib/graphql';
import { MULTI_THREADED_CONVERSATION_TYPE } from '../../tanuki_bot/constants';

// Matches the FieldCallCount limit on pinnedItemVersion (20)
export const CONFIGURED_AGENTS_PER_PAGE = 20;

export const ApolloUtils = {
  async createWorkflow(
    apollo,
    {
      projectId,
      workflowDefinition,
      namespaceId,
      goal,
      aiCatalogItemVersionId,
      agenticChatFlowRegistryMigration,
      webSearchEnabled,
    },
  ) {
    const defaultWorkflow = agenticChatFlowRegistryMigration
      ? DUO_WORKFLOW_NEW_CHAT_DEFINITION
      : DUO_WORKFLOW_CHAT_DEFINITION;

    const variables = {
      goal,
      workflowDefinition: workflowDefinition || defaultWorkflow,
      agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
      preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
      conversationType: MULTI_THREADED_CONVERSATION_TYPE,
      webSearchEnabled,
    };
    if (projectId) variables.projectId = projectId;
    if (namespaceId) variables.namespaceId = namespaceId;
    if (aiCatalogItemVersionId) variables.aiCatalogItemVersionId = aiCatalogItemVersionId;

    const result = await apollo.mutate({
      mutation: duoWorkflowMutation,
      variables,
      context: {
        featureCategory: 'duo_agent_platform',
        headers: {
          'X-GitLab-Interface': 'duo_chat',
          'X-GitLab-Client-Type': 'web_browser',
        },
      },
    });

    const errors = result?.data?.aiDuoWorkflowCreate?.errors;
    if (errors && errors.length > 0) {
      throw new Error(errors.join(', '));
    }

    const workflow = result?.data?.aiDuoWorkflowCreate?.workflow || {};

    return {
      workflowId: workflow.id ?? null,
    };
  },

  async updateWebSearch(apollo, { workflowId, webSearchEnabled }) {
    const { data } = await apollo.mutate({
      mutation: updateWebSearchMutation,
      variables: { workflowId, webSearchEnabled },
      context: {
        featureCategory: 'duo_agent_platform',
      },
    });

    const errors = data?.updateDuoWorkflowWebSearch?.errors;
    if (errors && errors.length > 0) {
      throw new Error(errors.join(', '));
    }
  },

  async deleteWorkflow(apollo, workflowId) {
    const { data } = await apollo.mutate({
      mutation: deleteAgenticWorkflowMutation,
      variables: { input: { workflowId } },
      context: {
        featureCategory: 'duo_agent_platform',
      },
    });

    const errors = data?.deleteDuoWorkflowsWorkflow?.errors;
    if (errors && errors.length > 0) {
      throw new Error(errors.join(', '));
    }

    return data?.deleteDuoWorkflowsWorkflow?.success;
  },

  async fetchWorkflowEvents(apollo, workflowId) {
    const { data } = await apollo.query({
      query: getWorkflowLatestCheckpointQuery,
      variables: { workflowId },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    });

    return data;
  },

  async getAgentFlowConfig(apollo, agentVersionId) {
    const { data } = await apollo.query({
      query: getAgentFlowConfig,
      variables: { agentVersionId },
      context: {
        featureCategory: 'duo_agent_platform',
      },
    });

    return data?.aiCatalogAgentFlowConfig;
  },
};

export function getCatalogAgentsQuery(queryVariables) {
  return {
    query: getConfiguredAgents,
    variables: {
      ...queryVariables,
      first: CONFIGURED_AGENTS_PER_PAGE,
    },
    context: {
      featureCategory: 'duo_agent_platform',
    },
  };
}

/**
 * Fetches the next page of configured agents if more pages exist.
 * Each page stays within the pinnedItemVersion FieldCallCount limit.
 *
 * @param {Object} apolloQuery - The Apollo smart query instance
 * @param {Object} pageInfo - The pageInfo from the current result
 * @returns {Promise<void>}
 */
export function fetchMoreConfiguredAgents(apolloQuery, pageInfo) {
  if (!pageInfo?.hasNextPage) return Promise.resolve();

  return apolloQuery.fetchMore({
    variables: {
      first: CONFIGURED_AGENTS_PER_PAGE,
      after: pageInfo.endCursor,
    },
    updateQuery: (previousResult, { fetchMoreResult }) => {
      return produce(fetchMoreResult, (draft) => {
        const prevNodes = previousResult.aiCatalogConfiguredItems?.nodes || [];
        const newNodes = draft.aiCatalogConfiguredItems?.nodes || [];
        draft.aiCatalogConfiguredItems.nodes = [...prevNodes, ...newNodes];
      });
    },
  });
}

export function getFoundationalAgentsQuery(queryVariables) {
  return {
    query: getFoundationalChatAgents,
    variables: queryVariables,
    context: {
      featureCategory: 'duo_agent_platform',
    },
    update(data) {
      return (
        data?.aiFoundationalChatAgents.nodes.map((agent) => ({
          ...agent,
          foundational: true,
        })) || []
      );
    },
  };
}
