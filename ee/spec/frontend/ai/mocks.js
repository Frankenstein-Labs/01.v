export const mockUser1 = {
  __typename: 'UserCore',
  id: 'gid://gitlab/User/1',
  avatarUrl: 'https://gitlab.com/uploads/-/system/user/avatar/1/avatar.png',
  name: 'Test User',
  username: 'testuser',
  webUrl: 'https://gitlab.com/testuser',
  webPath: '/testuser',
};

export const mockUser2 = {
  __typename: 'UserCore',
  id: 'gid://gitlab/User/2',
  avatarUrl: 'https://gitlab.com/uploads/-/system/user/avatar/2/avatar.png',
  name: 'Another User',
  username: 'anotheruser',
  webUrl: 'https://gitlab.com/anotheruser',
  webPath: '/anotheruser',
};

export const mockWorkItem = {
  id: 'gid://gitlab/WorkItem/42',
  iid: '42',
  webUrl: 'https://gitlab.com/gitlab-org/test-project/-/work_items/42',
};

export const mockMergeRequest = {
  id: 'gid://gitlab/MergeRequest/7',
  iid: '7',
  webUrl: 'https://gitlab.com/gitlab-org/test-project/-/merge_requests/7',
};

export const mockAgentFlowEdges = [
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/1',
      title: null,
      status: 'FINISHED',
      humanStatus: 'completed',
      updatedAt: '2024-01-01T00:00:00Z',
      workflowDefinition: 'software_development',
      modelMetadataName: 'claude_sonnet_4_6',
      modelMetadataIdentifier: 'claude-sonnet-4-20250514',
      user: mockUser1,
      workItem: null,
      mergeRequest: null,
      userPermissions: {
        updateDuoWorkflow: true,
        resumeDuoWorkflow: true,
      },
      project: {
        id: 'gid://gitlab/Project/1',
        name: 'Test Project',
        webUrl: 'https://gitlab.com/gitlab-org/test-project',
        fullPath: 'gitlab-org/test-project',
        namespace: {
          id: 'gid://gitlab/Group/1',
          name: 'gitlab-org',
          webUrl: 'https://gitlab.com/gitlab-org',
        },
      },
    },
  },
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/2',
      title: null,
      status: 'RUNNING',
      humanStatus: 'running',
      updatedAt: '2024-01-02T00:00:00Z',
      workflowDefinition: 'convert_to_gitlab_ci',
      modelMetadataName: 'claude_sonnet_4_6',
      modelMetadataIdentifier: 'claude-sonnet-4-20250514',
      user: mockUser1,
      workItem: null,
      mergeRequest: null,
      userPermissions: {
        updateDuoWorkflow: true,
        resumeDuoWorkflow: true,
      },
      project: {
        id: 'gid://gitlab/Project/2',
        name: 'Another Project',
        webUrl: 'https://gitlab.com/gitlab-org/another-project',
        fullPath: 'gitlab-org/another-project',
        namespace: {
          id: 'gid://gitlab/Group/1',
          name: 'gitlab-org',
          webUrl: 'https://gitlab.com/gitlab-org',
        },
      },
    },
  },
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/3',
      title: null,
      status: 'CREATED',
      humanStatus: 'created',
      updatedAt: '2024-01-03T00:00:00Z',
      workflowDefinition: 'chat',
      modelMetadataName: 'claude_sonnet_4_6',
      modelMetadataIdentifier: 'claude-sonnet-4-20250514',
      user: mockUser2,
      workItem: null,
      mergeRequest: null,
      userPermissions: {
        updateDuoWorkflow: false,
        resumeDuoWorkflow: false,
      },
      project: {
        id: 'gid://gitlab/Project/3',
        name: 'Chat Project',
        webUrl: 'https://gitlab.com/test-group/chat-project',
        fullPath: 'test-group/chat-project',
        namespace: {
          id: 'gid://gitlab/Group/2',
          name: 'test-group',
          webUrl: 'https://gitlab.com/test-group',
        },
      },
    },
  },
];

export const mockAgentFlows = mockAgentFlowEdges.map((edge) => edge.node);

export const mockAgentFlowsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
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
  },
};

export const mockDuoMessages = [
  {
    status: 'success',
    content: 'Starting workflow with goal: Hello world in JS',
    timestamp: '2025-07-03T13:24:14.467716+00:00',
    toolInfo: null,
    messageType: 'tool',
    correlationId: null,
    role: null,
    messageSubType: null,
    componentName: null,
    subsessionId: null,
  },
  {
    status: 'success',
    content:
      'I\'ll help you explore the GitLab project to understand the context for "Hello world in JS". Let me start by checking the current working directory and gathering information about the project structure.',
    timestamp: '2025-07-03T13:24:18.019182+00:00',
    toolInfo: null,
    messageType: 'agent',
    correlationId: null,
    role: null,
    messageSubType: null,
    componentName: null,
    subsessionId: null,
  },
];

export const mockGetAgentFlowResponse = {
  data: {
    duoWorkflowWorkflows: {
      edges: [
        {
          node: {
            __typename: 'DuoWorkflow',
            id: 'gid://gitlab/DuoWorkflow::Workflow/1',
            title: null,
            status: 'RUNNING',
            humanStatus: 'running',
            createdAt: '2023-01-01T00:00:00Z',
            updatedAt: '2024-01-01T00:00:00Z',
            workflowDefinition: 'software_development',
            modelMetadataName: 'claude_sonnet_4_6',
            modelMetadataIdentifier: 'claude-sonnet-4-20250514',
            lastExecutorLogsUrl: 'https://gitlab.com/gitlab-org/gitlab/-/jobs/456',
            allExecutorLogsUrls: ['https://gitlab.com/gitlab-org/gitlab/-/jobs/456'],
            latestCheckpoint: { duoMessages: mockDuoMessages },
            errors: null,
            user: mockUser1,
            workItem: null,
            mergeRequest: null,
            userPermissions: {
              updateDuoWorkflow: true,
              resumeDuoWorkflow: true,
            },
            project: {
              id: 'gid://gitlab/Project/1',
              name: 'Test Project',
              webUrl: 'https://gitlab.com/gitlab-org/test-project',
              fullPath: 'gitlab-org/test-project',
              namespace: {
                id: 'gid://gitlab/Group/1',
                name: 'gitlab-org',
                webUrl: 'https://gitlab.com/gitlab-org',
              },
            },
            summary: '',
          },
        },
      ],
    },
  },
};

export const mockCreateFlowResponse = {
  id: 1056241,
  project_id: 46519181,
  namespace_id: null,
  agent_privileges: [1, 2, 3, 4, 5],
  agent_privileges_names: [
    'read_write_files',
    'read_only_gitlab',
    'read_write_gitlab',
    'run_commands',
    'use_git',
  ],
  pre_approved_agent_privileges: [1, 2],
  pre_approved_agent_privileges_names: ['read_write_files', 'read_only_gitlab'],
  workflow_definition: 'developer/v1',
  status: 'created',
  allow_agent_to_request_user: true,
  image: null,
  environment: 'web',
  workload: {
    id: 1000338,
    message: null,
  },
  mcp_enabled: true,
  gitlab_url: 'https://gitlab.com',
};

export const mockAgentStatuses = [
  { reference: 'security-analyst', name: 'Security Analyst', enabled: true },
  { reference: 'code-reviewer', name: 'Code Reviewer', enabled: false },
  { reference: 'test-agent', name: 'Test Agent', enabled: null },
];

// agents with `enabled: null` are filtered out
export const expectedFilteredAgentStatuses = [
  { reference: 'security-analyst', name: 'Security Analyst', enabled: true },
  { reference: 'code-reviewer', name: 'Code Reviewer', enabled: false },
];

export const mockDuoWorkflowStatusCheckEnabled = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      duoWorkflowStatusCheck: {
        enabled: true,
        remoteFlowsEnabled: true,
        foundationalFlowsEnabled: true,
        createDuoWorkflowForCiAllowed: true,
      },
    },
  },
};

export const mockConfiguredFlowsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          id: 'gid://gitlab/Ai::CatalogItemConsumer/123',
          item: {
            id: 'gid://gitlab/Ai::CatalogItem/456',
            foundationalFlowReference: 'convert_to_gitlab_ci',
          },
        },
      ],
    },
  },
};

export const mockEmptyConfiguredFlowsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [],
    },
  },
};

/**
 * Shared mock data factories for Duo agent session specs:
 * - `buildSession` — individual DuoWorkflow session object
 * - `buildSessionGroup` — mapped group for AgentSessionsGroup
 * - `buildWorkItemSessionsQueryResponse` — wraps sessions in a getDuoAgentSessionsOnWorkItem response
 */

export const buildSession = (overrides = {}) => ({
  __typename: 'DuoWorkflow',
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1',
  title: '',
  status: 'FINISHED',
  humanStatus: 'Completed',
  createdAt: '2026-01-15T09:00:00Z',
  updatedAt: '2026-01-15T10:00:00Z',
  workflowDefinition: 'planner',
  user: null,
  project: {
    __typename: 'Project',
    id: 'gid://gitlab/Project/7',
    name: 'project',
    fullPath: 'group/project',
  },
  ...overrides,
});

export const buildSessionGroup = (overrides = {}) => ({
  key: 'INPUT_REQUIRED',
  title: '2 sessions awaiting your input',
  showViewDetails: true,
  sessions: [
    {
      id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1',
      status: 'INPUT_REQUIRED',
      humanStatus: 'Input required',
    },
    {
      id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/2',
      status: 'INPUT_REQUIRED',
      humanStatus: 'Input required',
    },
  ],
  representativeSession: { status: 'INPUT_REQUIRED', humanStatus: 'Input required' },
  ...overrides,
});

export const buildWorkItemSessionsQueryResponse = ({
  workItemId = 'gid://gitlab/WorkItem/1',
  nodes = [],
  hasNextPage = false,
} = {}) => ({
  data: {
    workItem: {
      __typename: 'WorkItem',
      id: workItemId,
      features: {
        __typename: 'WorkItemFeatures',
        aiSession: {
          __typename: 'WorkItemAiSession',
          duoWorkflows: {
            __typename: 'DuoWorkflowConnection',
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage,
            },
            nodes,
          },
        },
      },
    },
  },
});
