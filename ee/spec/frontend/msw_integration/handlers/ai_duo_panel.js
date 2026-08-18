import { join } from 'node:path';
import { cloneDeep } from 'lodash-es';
import { loadFixturesMap } from '../fixture_utils';

const FIXTURES_PATH = join('tmp/tests/frontend/fixtures-ee/graphql/ai_duo_panel/integration/');
const rawFixtures = loadFixturesMap(FIXTURES_PATH);

const threadNodes = rawFixtures.getAiConversationThreads.data.aiConversationThreads.nodes;

const workflowId = 'gid://gitlab/Ai::DuoWorkflows::Workflow/42';

const workflowCheckpoint = {
  id: workflowId,
  status: 'created',
  aiCatalogItemVersionId: null,
  workflowDefinition: 'default_chat_agent@1',
  archived: false,
  stalled: false,
  __typename: 'AiDuoWorkflowsWorkflow',
  latestCheckpoint: {
    workflowGoal: 'How do I refactor this function?',
    workflowStatus: 'created',
    errors: [],
    __typename: 'AiDuoWorkflowsCheckpoint',
    duoMessages: [
      {
        content: 'How do I refactor this function?',
        messageType: 'user',
        messageSubType: null,
        status: null,
        toolInfo: null,
        timestamp: '2026-04-19T10:00:00Z',
        correlationId: 'corr-1',
        messageId: 'msg-1',
        role: 'user',
        additionalContext: null,
        __typename: 'AiDuoWorkflowsMessage',
      },
      {
        content: 'You can extract the inner loop into a helper.',
        messageType: 'agent',
        messageSubType: null,
        status: 'completed',
        toolInfo: null,
        timestamp: '2026-04-19T10:00:02Z',
        correlationId: 'corr-2',
        messageId: 'msg-2',
        role: 'assistant',
        additionalContext: null,
        __typename: 'AiDuoWorkflowsMessage',
      },
    ],
  },
};

export const fixtures = {
  threads: threadNodes,
  messagesForFirstThread: rawFixtures.getAiMessagesWithThread.data.aiMessages.nodes,
  catalogAgents: rawFixtures.getConfiguredAgents.data.aiCatalogConfiguredItems.nodes,
  foundationalAgents: rawFixtures.getFoundationalChatAgents.data.aiFoundationalChatAgents.nodes,
  workflowId,
  workflowCheckpoint,
};

const threadWithMessagesId = threadNodes.find((t) => t.title !== null)?.id;

const FIXTURE_ONLY_KEY = 'getAiMessagesWithThreadEmpty';

const STATIC_HANDLERS = Object.fromEntries(
  Object.entries(rawFixtures)
    .filter(([key]) => key !== FIXTURE_ONLY_KEY)
    .map(([op, payload]) => [op, () => cloneDeep(payload)]),
);

const DYNAMIC_HANDLERS = {
  getAiMessagesWithThread: ({ variables }) =>
    cloneDeep(
      variables?.threadId === threadWithMessagesId
        ? rawFixtures.getAiMessagesWithThread
        : rawFixtures.getAiMessagesWithThreadEmpty,
    ),
  chat: ({ variables }) => ({
    data: {
      aiAction: {
        requestId: variables?.clientSubscriptionId ?? 'req-fixture-1',
        errors: [],
        threadId: variables?.threadId ?? null,
        __typename: 'AiActionPayload',
      },
    },
  }),
  getUserWorkflows: () => ({
    data: {
      duoWorkflowWorkflows: {
        edges: [
          {
            node: {
              id: fixtures.workflowId,
              lastUpdatedAt: '2026-04-19T12:00:00Z',
              title: 'How do I refactor this function?',
              aiCatalogItemVersionId: null,
              agentName: null,
              archived: false,
              stalled: false,
              __typename: 'AiDuoWorkflowsWorkflow',
            },
            __typename: 'AiDuoWorkflowsWorkflowEdge',
          },
        ],
        __typename: 'DuoWorkflowWorkflowConnection',
      },
    },
  }),
  getWorkflowLatestCheckpoint: () => ({
    data: {
      duoWorkflowWorkflows: {
        nodes: [fixtures.workflowCheckpoint],
        __typename: 'DuoWorkflowWorkflowConnection',
      },
    },
  }),

  // The classic chat state manager fires this on mount. Slash commands are not
  // exercised by these navigation tests, so return an empty list.
  getAiSlashCommands: () => ({
    data: {
      aiSlashCommands: [],
    },
  }),

  getAgentFlowConfig: () => ({
    data: {
      aiCatalogAgentFlowConfig: null,
    },
  }),

  // The Sessions tab of the panel. An empty list is enough to render the tab's
  // own empty state, which is all the panel-level specs need.
  getUserAgentFlows: () => ({
    data: {
      duoWorkflowWorkflows: {
        pageInfo: {
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
          __typename: 'PageInfo',
        },
        edges: [],
        __typename: 'DuoWorkflowConnection',
      },
    },
  }),

  getFlowTypes: () => ({
    data: {
      aiCatalogItems: {
        nodes: [],
        __typename: 'AiCatalogItemConnection',
      },
    },
  }),

  getDuoAgentSessionsOnWorkItem: () => ({
    data: {
      workItem: {
        id: 'gid://gitlab/WorkItem/1',
        features: {
          aiSession: {
            duoWorkflows: {
              nodes: [],
              __typename: 'DuoWorkflowWorkflowConnection',
            },
          },
        },
        __typename: 'WorkItem',
      },
    },
  }),

  dismissUserCallout: ({ variables }) => ({
    data: {
      userCalloutCreate: {
        errors: [],
        userCallout: {
          dismissedAt: '2026-04-20T00:00:00Z',
          featureName: variables?.input?.featureName ?? 'duo_panel_auto_expanded',
          __typename: 'UserCallout',
        },
        __typename: 'UserCalloutCreatePayload',
      },
    },
  }),
};

const OPERATION_HANDLERS = { ...STATIC_HANDLERS, ...DYNAMIC_HANDLERS };

export function handleAiDuoPanelEEOperation({ operationName, variables, res, ctx }) {
  const handler = OPERATION_HANDLERS[operationName];

  if (!handler) {
    return null;
  }

  return res(ctx.json(handler({ operationName, variables })));
}
