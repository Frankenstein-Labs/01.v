// Mock data for transformChatMessages tests
export const MOCK_AGENT_MESSAGE = { message_type: 'agent', content: 'Agent message' };
export const MOCK_REQUEST_MESSAGE = { message_type: 'request', content: 'Request message' };
export const MOCK_GENERIC_MESSAGE = { message_type: 'generic', content: 'Generic message' };
export const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
export const MOCK_NAMESPACE_ID = 'gid://gitlab/Group/456';
export const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflow/789';
export const MOCK_THREAD_ID = 'thread-123';
export const MOCK_GOAL = 'Optimize CI pipeline';
export const MOCK_ACTIVE_THREAD = 'active-thread-456';

export const MOCK_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    aiDuoWorkflowCreate: {
      workflow: {
        id: MOCK_WORKFLOW_ID,
        threadId: MOCK_THREAD_ID,
      },
      errors: [],
    },
  },
};

export const MOCK_DELETE_WORKFLOW_RESPONSE = {
  data: {
    deleteDuoWorkflowsWorkflow: {
      success: true,
      clientMutationId: null,
      errors: [],
    },
  },
};

export const MOCK_FETCH_WORKFLOW_LATEST_CHECKPOINT_RESPONSE = {
  data: {
    duoWorkflowWorkflows: {
      nodes: [
        {
          id: MOCK_WORKFLOW_ID,
          status: 'RUNNING',
          aiCatalogItemVersionId: null,
          workflowDefinition: null,
          archived: false,
          stalled: false,
          latestCheckpoint: {
            workflowGoal: MOCK_GOAL,
            workflowStatus: 'RUNNING',
            errors: [],
            duoMessages: [
              {
                content: 'Hello',
                messageType: 'agent',
                messageSubType: null,
                status: 'success',
                toolInfo: null,
                timestamp: '2025-11-18T09:52:43.756171+00:00',
                correlationId: 'msg-1',
                role: 'assistant',
                additionalContext: null,
              },
            ],
          },
        },
      ],
    },
  },
};

export const MOCK_ASSISTANT_MESSAGES = [
  { ...MOCK_AGENT_MESSAGE, message_id: 'msg-1' },
  { ...MOCK_REQUEST_MESSAGE, message_id: 'msg-2' },
];
export const MOCK_SINGLE_GENERIC_MESSAGE = [{ ...MOCK_GENERIC_MESSAGE, message_id: 'msg-3' }];
export const MOCK_MULTIPLE_USER_MESSAGES = [
  { message_type: 'user', content: 'First', message_id: 'msg-4' },
  { message_type: 'user', content: 'Second', message_id: 'msg-5' },
  { message_type: 'user', content: 'Third', message_id: 'msg-6' },
];
export const MOCK_USER_MESSAGE_WITH_PROPERTIES = [
  {
    message_type: 'user',
    message_id: 'msg-7',
    content: 'Test message',
    timestamp: '2025-07-25T14:30:00Z',
    customProperty: 'should be preserved',
    metadata: { key: 'value' },
  },
];

export const MOCK_PARSE_WORKFLOW_RESPONSE = {
  duoWorkflowWorkflows: {
    nodes: [
      {
        id: 'workflow-1',
        status: 'RUNNING',
        latestCheckpoint: {
          workflowGoal: 'Test goal',
          workflowStatus: 'RUNNING',
          errors: [],
          duoMessages: [
            {
              content: 'Hello',
              messageType: 'agent',
              messageId: 'executor-msg-1',
              correlationId: 'client-corr-1',
            },
          ],
        },
      },
    ],
  },
};

export const MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE = {
  duoWorkflowWorkflows: {
    nodes: [],
  },
};

export const MOCK_PARSE_WORKFLOW_WITH_CHECKPOINT_RESPONSE = {
  duoWorkflowWorkflows: {
    nodes: [
      {
        id: 'workflow-1',
        status: 'CREATED',
        latestCheckpoint: null,
      },
    ],
  },
};

export const MOCK_AGENT_FLOW_CONFIG_RESPONSE = {
  data: {
    aiCatalogAgentFlowConfig: {
      flowConfig: 'YAML STRING',
    },
  },
};

export const MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE = {
  data: {
    aiFoundationalChatAgents: {
      nodes: [
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
        },
        {
          id: 'gid://gitlab/Ai::FoundationalChatAgent/agent-v1',
          name: 'Cool agent',
          description: 'An agent that makes things cooler',
          referenceWithVersion: 'agent/v1',
          flowConfig: null,
        },
      ],
    },
  },
};

export const MOCK_CHAT_MESSAGES = {
  prompt: {
    message_id: 0,
    content: 'Update the README to explain the main languages used in the project',
    role: 'user',
  },
  user: {
    message_id: 0,
    message_sub_type: null,
    message_type: 'user',
    content: 'Update the README to explain the main languages used in the project',
    timestamp: '2025-11-18T09:52:38.523380+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: null,
    additional_context: [
      {
        category: 'repository',
        id: '',
        content:
          '<current_gitlab_page_url>gdk.test:8080/gitlab-duo/test</current_gitlab_page_url>\n<current_gitlab_page_title>GitLab Duo / Test · GitLab</current_gitlab_page_title>',
        metadata: {},
        type: 'AdditionalContext',
      },
    ],
    role: 'user',
  },
  agentStreaming: {
    message_id: 1,
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:43.756171+00:00',
    content: "I'll update",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agentStreaming1: {
    message_id: 1,
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:43.756171+00:00',
    content: "I'll update the README to explain the main languages",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agentComplete: {
    message_id: 1,
    message_type: 'agent',
    message_sub_type: null,
    content:
      "I'll update the README to explain the main languages used in the project. First, let me get the current README content.",
    timestamp: '2025-11-18T09:52:45.082275+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  tool: {
    message_id: 2,
    message_type: 'tool',
    message_sub_type: 'get_repository_file',
    content: 'Get repository file README.md from project 1000000 at ref HEAD',
    timestamp: '2025-11-18T09:52:45.530655+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: {
      name: 'get_repository_file',
      args: {
        project_id: 1000000,
        file_path: 'README.md',
        ref: 'HEAD',
      },
      tool_response: {
        content:
          '# Test project for GitLab Duo\\n\\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.',
        additional_kwargs: {},
        response_metadata: {},
        type: 'ToolMessage',
        name: 'get_repository_file',
        id: null,
        tool_call_id: 'toolu_vrtx_016EoHinnPT6nxKTHookKNDL',
        artifact: null,
        status: 'success',
      },
    },
    additional_context: null,
    role: 'tool',
  },
  agent2Streaming1: {
    message_id: 3,
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:47.922360+00:00',
    content: 'Now',
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agent2Streaming2: {
    message_id: 3,
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:47.922360+00:00',
    content: "Now I'll update the README to",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  request: {
    message_id: 3,
    status: 'success',
    content: 'Tool create_commit requires approval. Please confirm if you want to proceed.',
    timestamp: '2025-11-18T09:52:54.430519+00:00',
    tool_info: {
      args: {
        actions: [
          {
            action: 'update',
            new_str:
              '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.\n\n',
            old_str:
              '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.',
            file_path: 'README.md',
          },
        ],
        project_id: 1000000,
        commit_message: 'Update README to explain main languages used in the project',
      },
      name: 'create_commit',
    },
    message_type: 'request',
    correlation_id: null,
    message_sub_type: null,
    additional_context: null,
    role: 'assistant',
  },
  tool3Fail: [
    {
      message_id: 4,
      message_type: 'tool',
      message_sub_type: 'create_commit',
      content:
        'Failed: Create commit in project 1000000 on new auto-created branch with 1 file action (update) - Tool call failed: ToolException',
      timestamp: '2025-11-18T10:34:57.625572+00:00',
      status: 'failure',
      correlation_id: null,
      tool_info: {
        name: 'create_commit',
        args: {
          actions: [
            {
              action: 'update',
              content: '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo.',
              file_path: 'README.md',
            },
          ],
          project_id: 1000000,
          commit_message: 'Update README to explain main languages used in the project',
        },
      },
      additional_context: null,
      role: 'tool',
    },
    {
      message_id: 5,
      status: null,
      correlation_id: null,
      message_type: 'agent',
      message_sub_type: null,
      timestamp: '2025-11-14T10:15:45.971730+00:00',
      content: 'Let me try with the full content approach:',
      tool_info: null,
      additional_context: null,
      role: 'assistant',
    },
  ],
};
