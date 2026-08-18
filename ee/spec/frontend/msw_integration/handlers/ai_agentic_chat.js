// MSW handlers for Duo Agentic Chat GraphQL operations.
// Tests can mutate `fixtures` between mounts to vary responses (e.g. mark
// a workflow archived) without re-importing the module.

import { join } from 'node:path';
import { loadFixturesMap } from '../fixture_utils';

// Static responses whose shape must track the schema are sourced from the
// generated fixtures. The archived/active workflow variation below stays inline
// because it drives per-test mutation and has no single generatable response.
const FIXTURES_PATH = join('tmp/tests/frontend/fixtures-ee/graphql/ai/duo_agentic_chat/');
const generatedFixtures = loadFixturesMap(FIXTURES_PATH);

const archivedWorkflow = {
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/100',
  title: 'Refactor this very old conversation',
  lastUpdatedAt: '2026-01-01T00:00:00Z',
  aiCatalogItemVersionId: null,
  agentName: 'GitLab Duo',
  archived: true,
  stalled: false,
  __typename: 'DuoWorkflow',
};

const activeWorkflow = {
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/200',
  title: 'Plan today’s release',
  lastUpdatedAt: '2026-05-08T00:00:00Z',
  aiCatalogItemVersionId: null,
  agentName: 'GitLab Duo',
  archived: false,
  stalled: false,
  __typename: 'DuoWorkflow',
};

const workflowEventsFor = (workflow) => ({
  data: {
    duoWorkflowEvents: {
      nodes: [
        {
          checkpoint: '{"channel_values": {"ui_chat_log": []}}',
          errors: null,
          metadata: null,
          workflowGoal: workflow.title,
          workflowStatus: 'completed',
          __typename: 'DuoWorkflowEvent',
        },
      ],
      __typename: 'DuoWorkflowEventConnection',
    },
    duoWorkflowWorkflows: {
      nodes: [
        {
          id: workflow.id,
          status: 'completed',
          aiCatalogItemVersionId: workflow.aiCatalogItemVersionId,
          workflowDefinition: null,
          archived: workflow.archived,
          stalled: false,
          __typename: 'DuoWorkflow',
        },
      ],
      __typename: 'DuoWorkflowConnection',
    },
  },
});

// Opt-in flag: handler returns null for shared operations (getUserWorkflows,
// getDuoWorkflowEvents) unless a test has called resetFixtures(). This keeps
// other integration suites (e.g. new_conversation_spec) on the duo-panel
// handler's defaults instead of this module's archived/active fixtures.
let opted = false;

export const fixtures = {
  archivedWorkflow,
  activeWorkflow,
  // Drives `getUserWorkflows`. Tests can reassign this array to vary the list.
  userWorkflows: [archivedWorkflow, activeWorkflow],
  // Drives `getDuoWorkflowEvents`. Map keyed by workflow id; tests can set an
  // override here to return an empty-nodes response for a specific id.
  workflowEventsOverrides: {},
};

export function resetFixtures() {
  fixtures.userWorkflows = [archivedWorkflow, activeWorkflow];
  fixtures.workflowEventsOverrides = {};
  opted = true;
}

export function disableAgenticChatFixtures() {
  opted = false;
}

const emptyPageInfo = {
  hasNextPage: false,
  endCursor: null,
  __typename: 'PageInfo',
};

const AGENTIC_CHAT_OPERATIONS = {
  getUserWorkflows: () => ({
    data: {
      duoWorkflowWorkflows: {
        edges: fixtures.userWorkflows.map((node) => ({ node, __typename: 'DuoWorkflowEdge' })),
        __typename: 'DuoWorkflowConnection',
      },
    },
  }),

  getDuoWorkflowEvents: ({ variables }) => {
    const workflowId = variables?.workflowId;
    const override = fixtures.workflowEventsOverrides[workflowId];
    if (override) return override;

    const workflow = fixtures.userWorkflows.find((w) => w.id === workflowId);
    if (!workflow) {
      return {
        data: {
          duoWorkflowEvents: {
            nodes: [],
            __typename: 'DuoWorkflowEventConnection',
          },
          duoWorkflowWorkflows: {
            nodes: [],
            __typename: 'DuoWorkflowConnection',
          },
        },
      };
    }
    return workflowEventsFor(workflow);
  },

  getAiChatContextPresets: () => generatedFixtures.getAiChatContextPresets,

  getGitlabCreditsStatus: () => generatedFixtures.getGitlabCreditsStatus,

  getFoundationalChatAgents: () => ({
    data: {
      aiFoundationalChatAgents: {
        nodes: [],
        __typename: 'AiFoundationalChatAgentConnection',
      },
    },
  }),

  getFlowStatus: ({ variables }) => ({
    data: {
      duoWorkflowWorkflows: {
        edges: [
          {
            node: {
              id: variables?.id,
              status: 'completed',
              __typename: 'DuoWorkflow',
            },
            __typename: 'DuoWorkflowEdge',
          },
        ],
        __typename: 'DuoWorkflowConnection',
      },
    },
  }),

  createAiDuoWorkflow: () => ({
    data: {
      aiDuoWorkflowCreate: {
        workflow: {
          id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/999',
          __typename: 'DuoWorkflow',
        },
        errors: [],
        __typename: 'AiDuoWorkflowCreatePayload',
      },
    },
  }),

  deleteDuoWorkflowsWorkflow: () => ({
    data: {
      deleteDuoWorkflowsWorkflow: {
        success: true,
        clientMutationId: null,
        errors: [],
        __typename: 'DeleteDuoWorkflowsWorkflowPayload',
      },
    },
  }),

  // The agentic configured-items query shares an operationName with the
  // panel-level catalog handler. We return a superset shape so both code
  // paths are satisfied without needing variant detection.
  getConfiguredAgents: () => ({
    data: {
      aiCatalogConfiguredItems: {
        nodes: [],
        pageInfo: { ...emptyPageInfo },
        __typename: 'AiCatalogConfiguredItemConnection',
      },
    },
  }),
};

export function handleAiAgenticChatOperation({ operationName, variables, res, ctx }) {
  if (!opted) return null;

  const handler = AGENTIC_CHAT_OPERATIONS[operationName];
  if (!handler) return null;

  const payload = handler({ operationName, variables });
  return res(ctx.json(payload));
}
