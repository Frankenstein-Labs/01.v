import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';

export const MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE = {
  data: {
    aiChatAvailableModels: {
      defaultModel: {
        name: 'Claude Sonnet 4.0',
        ref: 'claude_sonnet_4_20250514',
        modelProvider: 'Anthropic',
        modelDescription: 'Fast, cost-effective responses.',
        costIndicator: '$$$',
      },
      selectableModels: [
        {
          name: 'Claude Sonnet 4.0',
          ref: 'claude_sonnet_4_20250514',
          modelProvider: 'Anthropic',
          modelDescription: 'Fast, cost-effective responses.',
          costIndicator: '$$$',
        },
        {
          name: 'Claude Sonnet 3.5',
          ref: 'claude_3_5_sonnet_20240620',
          modelProvider: 'Anthropic',
          modelDescription: 'Fast, cost-effective responses.',
          costIndicator: '$$',
        },
      ],
      pinnedModel: null,
    },
  },
};

export const MOCK_GITLAB_DEFAULT_MODEL_ITEM = {
  value: GITLAB_DEFAULT_MODEL,
  text: 'Claude Sonnet 4.0 - Default',
  modelProvider: 'Anthropic',
  modelDescription: 'Fast, cost-effective responses.',
  costIndicator: '$$$',
};

export const MOCK_MODEL_LIST_ITEMS = [
  {
    text: 'Claude Sonnet 4.0 - Default',
    value: GITLAB_DEFAULT_MODEL,
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
    costIndicator: '$$$',
  },
  {
    text: 'Claude Sonnet 3.5',
    value: 'claude_3_5_sonnet_20240620',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
    costIndicator: '$$',
  },
];

export const MOCK_CONFIGURED_AGENTS_RESPONSE = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          id: 'Configured Item 5',
          pinnedVersionPrefix: '1.0.0',
          pinnedItemVersion: {
            id: 'AgentVersion 5',
            versionName: '1.0.0',
            tools: { nodes: [] },
            mcpTools: [],
          },
          item: {
            id: 'Agent 5',
            name: 'My Custom Agent',
            description: 'This is my custom agent',
            itemType: 'AGENT',
            foundational: false,
            latestVersion: {
              id: 'AgentVersion 5',
              versionName: '1.0.0',
            },
          },
        },
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: 'start',
        endCursor: 'end',
      },
      __typename: 'AiCatalogItemConsumerConnection',
    },
  },
};

export const DUO_CHAT_AGENT_MOCK = {
  id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
  name: 'GitLab Duo Agent',
  description: 'Duo is your general development assistant',
  reference: 'chat',
  referenceWithVersion: 'chat',
  version: null,
  avatarUrl: '/assets/bot_avatars/gitlab-duo-agent.png',
  selectableInChat: true,
  tools: [],
  flowConfig: {
    flowConfigId: 'chat',
    flowConfigSchemaVersion: null,
    flowVersion: '^1.0.0',
  },
};

export const DUO_FOUNDATIONAL_AGENT_MOCK = {
  id: 'gid://gitlab/Ai::FoundationalChatAgent/agent-v1',
  name: 'Cool agent',
  description: 'An agent that makes things cooler',
  reference: 'agent',
  referenceWithVersion: 'agent/v1',
  version: 'v1',
  foundational: true,
  avatarUrl: '/assets/bot_avatars/gitlab-duo-agent.png',
  selectableInChat: true,
  tools: [],
  flowConfig: null,
};

export const MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE = {
  data: {
    aiFoundationalChatAgents: {
      nodes: [DUO_CHAT_AGENT_MOCK, DUO_FOUNDATIONAL_AGENT_MOCK],
    },
  },
};

export const MOCK_FETCHED_FOUNDATIONAL_AGENT = {
  ...DUO_FOUNDATIONAL_AGENT_MOCK,
  text: DUO_FOUNDATIONAL_AGENT_MOCK.name,
  foundational: true,
};

export const MOCK_FLOW_AGENT_CONFIG = 'components:\n  - name: test\n    type: agent';
export const MOCK_FLOW_CONFIG_RESPONSE = {
  data: { aiCatalogAgentFlowConfig: MOCK_FLOW_AGENT_CONFIG },
};

const buildCheckpointResponse = (duoMessages, status = 'RUNNING') => ({
  data: {
    duoWorkflowWorkflows: {
      nodes: [
        {
          id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/326',
          status,
          aiCatalogItemVersionId: null,
          workflowDefinition: 'fix_pipeline/v1',
          archived: false,
          stalled: false,
          webSearchEnabled: false,
          latestCheckpoint: {
            workflowGoal: 'Test goal',
            workflowStatus: status,
            errors: null,
            duoMessages,
          },
        },
      ],
    },
  },
});

export const MOCK_LATEST_CHECKPOINT_WITH_TODO = buildCheckpointResponse([
  {
    content: 'Planning…',
    messageType: 'tool',
    messageSubType: null,
    status: 'success',
    toolInfo: JSON.stringify({
      name: 'todo_write',
      args: {
        todos: [
          { status: 'completed', description: 'Read pipeline logs' },
          { status: 'in_progress', description: 'Identify failing job' },
          { status: 'pending', description: 'Apply fix' },
        ],
      },
    }),
    timestamp: '2026-03-26T12:50:00.000000+00:00',
    correlationId: 'corr-1',
    messageId: 'msg-1',
    role: 'assistant',
    additionalContext: null,
  },
]);

const READ_FILE_MESSAGES = [
  {
    content: 'Reading file',
    messageType: 'tool',
    messageSubType: null,
    status: 'success',
    toolInfo: JSON.stringify({ name: 'read_file', args: { path: 'foo.rb' } }),
    timestamp: '2026-03-26T12:50:00.000000+00:00',
    correlationId: 'corr-2',
    messageId: 'msg-2',
    role: 'assistant',
    additionalContext: null,
  },
];

export const MOCK_LATEST_CHECKPOINT = buildCheckpointResponse(READ_FILE_MESSAGES);

export const MOCK_LATEST_CHECKPOINT_FINISHED = buildCheckpointResponse(
  READ_FILE_MESSAGES,
  'FINISHED',
);

export const MOCK_LATEST_CHECKPOINT_EMPTY = buildCheckpointResponse([]);

export const MOCK_LATEST_CHECKPOINT_FINISHED_WITH_TODO = buildCheckpointResponse(
  [
    {
      content: 'Planning…',
      messageType: 'tool',
      messageSubType: null,
      status: 'success',
      toolInfo: JSON.stringify({
        name: 'todo_write',
        args: {
          todos: [
            { status: 'completed', description: 'Read pipeline logs' },
            { status: 'completed', description: 'Apply fix' },
          ],
        },
      }),
      timestamp: '2026-03-26T12:50:00.000000+00:00',
      correlationId: 'corr-3',
      messageId: 'msg-3',
      role: 'assistant',
      additionalContext: null,
    },
  ],
  'FINISHED',
);

export const MOCK_START_FLOW_TOOL_MESSAGE = {
  status: 'success',
  content:
    'Started flow **fix_pipeline/v1** (workflow ID: 326) — [View session](https://example.com/gitlab-duo/test/-/automate/agent-sessions/326)',
  timestamp: '2026-03-26T12:49:34.958100+00:00',
  tool_info: {
    args: {
      goal: 'https://example.com/gitlab-duo/test/-/pipelines/1251',
      inputs: {
        'pipeline.source_branch': 'duo-edit-20260305-174345',
      },
      workflow_definition: 'fix_pipeline/v1',
    },
    name: 'start_flow',
    tool_response: {
      id: null,
      name: 'start_flow',
      type: 'ToolMessage',
      status: 'success',
      content:
        '{"status": "started", "workflow_id": 326, "session_url": "https://example.com/gitlab-duo/test/-/automate/agent-sessions/326", "flow_name": "fix_pipeline/v1"}',
      artifact: null,
      tool_call_id: 'toolu_01UHJB96arU3umrDSbxeFW7H',
      additional_kwargs: {},
      response_metadata: {},
    },
  },
  message_id: 'toolu_01UHJB96arU3umrDSbxeFW7H',
  message_type: 'tool',
  correlation_id: null,
  message_sub_type: 'start_flow',
  additional_context: null,
};
