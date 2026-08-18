export const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';
const TYPENAME_AI_CATALOG_ITEM_STAR = 'AiCatalogItemStarPayload';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER = 'AiCatalogItemConsumer';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE = 'AiCatalogItemConsumerUpdate';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE = 'AiCatalogItemConsumerDeletePayload';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION = 'AiCatalogItemConsumerConnection';
const TYPENAME_AI_CATALOG_AGENT = 'AiCatalogAgent';
const TYPENAME_AI_CATALOG_AGENT_CREATE = 'AiCatalogAgentCreatePayload';
const TYPENAME_AI_CATALOG_AGENT_UPDATE = 'AiCatalogAgentUpdatePayload';
const TYPENAME_AI_CATALOG_AGENT_DELETE = 'AiCatalogAgentDeletePayload';
const TYPENAME_AI_CATALOG_AGENT_VERSION = 'AiCatalogAgentVersion';
const TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION = 'AiCatalogBuiltInToolConnection';
const TYPENAME_AI_CATALOG_FLOW = 'AiCatalogFlow';
const TYPENAME_AI_CATALOG_FLOW_VERSION = 'AiCatalogFlowVersion';
const TYPENAME_AI_CATALOG_FLOW_CREATE = 'AiCatalogFlowCreatePayload';
const TYPENAME_AI_CATALOG_FLOW_UPDATE = 'AiCatalogFlowUpdatePayload';
const TYPENAME_AI_CATALOG_FLOW_DELETE = 'AiCatalogFlowDeletePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_CREATE = 'AiCatalogThirdPartyFlowCreatePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_UPDATE = 'AiCatalogThirdPartyFlowCreatePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION = 'AiCatalogThirdPartyFlowVersion';
const TYPENAME_AI_FLOW_TRIGGER = 'AiFlowTriggerType';
export const TYPENAME_GROUP = 'Group';
export const TYPENAME_PROJECT = 'Project';
const TYPENAME_PROJECTS_CONNECTION = 'ProjectsConnection';
const TYPENAME_AI_CATALOG_ITEM_REPORT = 'AiCatalogItemReportPayload';
const TYPENAME_USER = 'User';
const TYPENAME_AI_CATALOG_MCP_SERVER = 'AiCatalogMcpServer';
const TYPENAME_AI_CATALOG_MCP_SERVER_CREATE = 'AiCatalogMcpServerCreatePayload';
const TYPENAME_AI_CATALOG_MCP_SERVER_UPDATE = 'AiCatalogMcpServerUpdatePayload';
const VERIFICATION_LEVEL_GITLAB_MAINTAINED = 'GITLAB_MAINTAINED';

export const mockCreatedByUser = {
  id: 'gid://gitlab/User/1',
  name: 'Test User',
  username: 'testuser',
  webUrl: 'https://gitlab.com/testuser',
  __typename: TYPENAME_USER,
};

export const mockModifiedByUser = {
  id: 'gid://gitlab/User/2',
  name: 'Another User',
  username: 'anotheruser',
  human: true,
  webUrl: 'https://gitlab.com/anotheruser',
  __typename: TYPENAME_USER,
};

const mockVersionFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
  versionName: '1.0.0',
  createdAt: '2025-08-21T14:30:00Z',
  updatedAt: '2025-08-21T14:30:00Z',
  createdBy: {
    id: 'gid://gitlab/User/1',
    name: 'Test User',
    username: 'testuser',
    webUrl: 'https://gitlab.com/testuser',
  },
  ...overrides,
});

const mockVersionCreatedByWithUsername = {
  id: 'gid://gitlab/User/1',
  name: 'Test User',
  username: 'testuser',
  webUrl: 'https://gitlab.com/testuser',
};

export const mockBaseVersion = mockVersionFactory();

export const mockProjectFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Project/1',
  __typename: TYPENAME_PROJECT,
  ...overrides,
});

const mockUserPermissionsFactory = (overrides = {}) => ({
  adminAiCatalogItem: true,
  ...overrides,
});

const mockItemConsumerUserPermissionsFactory = (overrides = {}) => ({
  adminAiCatalogItemConsumer: true,
  ...overrides,
});

const mockUserPermissions = mockUserPermissionsFactory();
const mockItemConsumerUserPermissions = mockItemConsumerUserPermissionsFactory();

export const mockProjectWithNamespace = mockProjectFactory({
  nameWithNamespace: 'Group / Project 1',
});

export const mockProjectWithGroup = mockProjectFactory({
  name: 'Project 1',
  nameWithNamespace: 'Group / Project 1',
  webUrl: 'https://gitlab.com/gitlab-org/test-project',
  rootGroup: {
    id: 'gid://gitlab/Group/1',
    fullName: 'Group 1',
    fullPath: 'group-1',
    __typename: TYPENAME_GROUP,
  },
});

export const mockPageInfo = {
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjUxIn0',
  endCursor: 'eyJpZCI6IjM1In0',
  __typename: 'PageInfo',
};

export const mockProjects = [
  mockProjectFactory({
    id: 'gid://gitlab/Project/1',
    name: 'Project 1',
    nameWithNamespace: 'Group / Project 1',
  }),
  mockProjectFactory({
    id: 'gid://gitlab/Project/2',
    name: 'Project 2',
    nameWithNamespace: 'Group / Project 2',
  }),
];

export const mockProjectsResponse = {
  data: {
    projects: {
      nodes: mockProjects,
      pageInfo: mockPageInfo,
      count: 2,
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockNextPageProjects = [
  mockProjectFactory({
    id: 'gid://gitlab/Project/3',
    name: 'Project 3',
    nameWithNamespace: 'Group / Project 3',
  }),
  mockProjectFactory({
    id: 'gid://gitlab/Project/4',
    name: 'Project 4',
    nameWithNamespace: 'Group / Project 4',
  }),
];

export const mockNextPageProjectsResponse = {
  data: {
    projects: {
      nodes: mockNextPageProjects,
      pageInfo: { ...mockPageInfo, hasNextPage: false },
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockAvailableProjectsResponse = {
  data: {
    projects: {
      count: 2,
      nodes: [
        {
          ...mockProjects[0],
          aiCatalogItemConsumerForItem: null,
        },
        {
          ...mockProjects[1],
          aiCatalogItemConsumerForItem: {
            id: 'gid://gitlab/Ai::Catalog::ItemConsumer/10',
            enabled: true,
            __typename: 'AiCatalogItemConsumer',
          },
        },
      ],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockEmptyProjectsResponse = {
  data: {
    projects: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockToolsIds = [
  'gid://gitlab/Ai::Catalog::BuiltInTool/1',
  'gid://gitlab/Ai::Catalog::BuiltInTool/2',
  'gid://gitlab/Ai::Catalog::BuiltInTool/3',
];

export const mockAiCatalogBuiltInToolsNodes = [
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/3`,
    title: 'CI Linter',
    name: 'ci_linter',
    description: 'CI Linter Tool description',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/2`,
    title: 'Gitlab Blob Search',
    name: 'gitlab_blob_search',
    description: 'Gitlab Blob Search Tool description',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/1`,
    title: 'Run Git Command',
    name: 'run_git_command',
    description: 'Run Git Command Tool description',
  },
];

export const mockToolsQueryResponse = {
  data: {
    aiCatalogBuiltInTools: {
      nodes: mockAiCatalogBuiltInToolsNodes,
      __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
    },
  },
};

export const mockGitlabMcpIcons = [
  { src: '/assets/gitlab_logo.png', mimeType: 'image/png', theme: 'light' },
  { src: '/assets/gitlab_logo.png', mimeType: 'image/png', theme: 'dark' },
];

export const mockAiMcpToolsNodes = [
  {
    name: 'search',
    title: 'Search',
    description: 'Search tool description',
    icons: mockGitlabMcpIcons,
  },
  {
    name: 'semantic_code_search',
    title: 'Semantic Code Search',
    description: 'Semantic Code Search tool description',
    icons: mockGitlabMcpIcons,
  },
];

export const mockMcpToolsQueryResponse = {
  data: {
    aiCatalogMcpTools: {
      nodes: mockAiMcpToolsNodes,
    },
  },
};

export const mockMcpServers = [
  {
    id: 'gid://gitlab/Ai::Catalog::McpServer/1',
    name: 'Test MCP Server 1',
    description: 'Test MCP Server 1 description',
    url: 'https://mcp1.example.com',
    homepageUrl: 'https://mcp1.example.com',
    transport: 'HTTP',
    authType: 'NONE',
    oauthClientId: null,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    __typename: TYPENAME_AI_CATALOG_MCP_SERVER,
  },
  {
    id: 'gid://gitlab/Ai::Catalog::McpServer/2',
    name: 'Test MCP Server 2',
    description: 'Test MCP Server 2 description',
    url: 'https://mcp2.example.com',
    homepageUrl: 'https://mcp2.example.com',
    transport: 'HTTP',
    authType: 'NONE',
    oauthClientId: null,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    __typename: TYPENAME_AI_CATALOG_MCP_SERVER,
  },
];

export const mockMcpServersQueryResponse = {
  data: {
    aiCatalogMcpServers: {
      nodes: mockMcpServers,
      pageInfo: mockPageInfo,
      __typename: 'AiCatalogMcpServerConnection',
    },
  },
};

export const mockMcpServersEmptyQueryResponse = {
  data: {
    aiCatalogMcpServers: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
        __typename: 'PageInfo',
      },
      __typename: 'AiCatalogMcpServerConnection',
    },
  },
};

/* AGENTS */

export const mockItemTypeConfig = {
  showRoute: 'show',
  visibilityTooltip: {
    Public: 'This item is publicly available.',
    Private: 'This item is private.',
  },
};

const mockAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  descriptionHtml: null,
  foundationalFlowReference: null,
  foundationalAgentReference: null,
  createdAt: '2024-01-15T10:30:00Z',
  softDeleted: false,
  public: true,
  visibility: 'PUBLIC',
  updatedAt: '2024-08-21T14:30:00Z',
  latestVersion: mockBaseVersion,
  userPermissions: mockUserPermissions,
  __typename: TYPENAME_AI_CATALOG_AGENT,
  foundational: false,
  starCount: 0,
  starred: false,
  last30DayUsageCount: 0,
  verificationLevel: 'UNVERIFIED',
  ...overrides,
});

export const mockAgentVersion = {
  ...mockBaseVersion,
  createdAt: '2024-01-15T10:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt',
  tools: {
    nodes: [],
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
  mcpTools: [],
  mcpServers: {
    nodes: [],
    __typename: 'AiCatalogMcpServerConnection',
  },
};

export const mockAgentPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/2' }),
  createdAt: '2025-08-20T14:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt pinned',
  tools: {
    nodes: mockAiCatalogBuiltInToolsNodes,
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
  mcpTools: [],
  mcpServers: {
    nodes: [],
    __typename: 'AiCatalogMcpServerConnection',
  },
};

export const mockAgentGroupPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/3' }),
  createdAt: '2025-08-19T14:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v0.8.0',
  versionName: '0.8.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt group pinned version',
  tools: {
    nodes: mockAiCatalogBuiltInToolsNodes,
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
  mcpTools: [],
  mcpServers: {
    nodes: [],
    __typename: 'AiCatalogMcpServerConnection',
  },
};

export const mockBaseAgent = mockAgentFactory();

export const mockAgent = mockAgentFactory({
  project: mockProjectWithGroup,
  latestVersion: mockAgentVersion,
});

// A foundational chat agent when received through the `AiCatalogAgent` GraphQL type.
// This is distinct from `mockFoundationalAgent` (received through the
// `AiFoundationalChatAgent` GraphQL type), which will eventually replace this.
export const mockFoundationalCatalogAgent = mockAgentFactory({
  project: mockProjectWithGroup,
  latestVersion: mockAgentVersion,
  foundational: true,
  foundationalAgentReference: 'orbit_agent',
  verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
});

export const mockAgents = [
  mockAgentFactory({
    project: mockProjectWithNamespace,
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    public: false,
    visibility: 'RESTRICTED',
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    public: false,
    visibility: 'PRIVATE',
  }),
];

const mockAgentVersionFactory = (overrides = {}) => ({
  ...mockVersionFactory(),
  createdBy: mockVersionCreatedByWithUsername,
  humanVersionName: 'v1.0.0',
  versionName: '1.0.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  ...overrides,
});

export const mockAgentsWithConfig = [
  mockAgentFactory({
    project: mockProjectWithNamespace,
    latestVersion: mockAgentVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
      humanVersionName: 'v1.1.0',
      versionName: '1.1.0',
    }),
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
      enabled: true,
      pinnedItemVersion: mockAgentVersionFactory({
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/2',
      }),
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    latestVersion: mockAgentVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/3',
    }),
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/2',
      enabled: true,
      pinnedItemVersion: mockAgentVersionFactory({
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/4',
      }),
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/15',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    latestVersion: mockAgentVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/5',
    }),
    public: false,
    visibility: 'PRIVATE',
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
      enabled: true,
      pinnedItemVersion: mockAgentVersionFactory({
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/6',
      }),
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/16',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
];

const mockFoundationalAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::FoundationalChatAgent/security_analyst_agent-v1',
  name: 'Security Analyst',
  reference: 'security_analyst_agent',
  itemType: 'FOUNDATIONAL_AGENT',
  avatarUrl: '/assets/bot_avatars/security-agent',
  description: 'Automate vulnerability management and security workflows',
  referenceWithVersion: 'security_analyst_agent/v1',
  systemPrompt: 'You are the GitLab Security Analyst Agent',
  tools: [{ id: 'gid://gitlab/Ai::Catalog::BuiltInTool/4', title: 'Gitlab Commit Search' }],
  version: 'v1',
  __typename: 'AiFoundationalChatAgent',
  ...overrides,
});

export const mockFoundationalAgent = mockFoundationalAgentFactory();

export const mockCustomAndFoundationalItems = [...mockAgents, mockFoundationalAgent];

export const mockCatalogItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockAgents,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCatalogCustomAndFoundationalItemsResponse = {
  data: {
    aiCatalogCustomAndFoundationalItems: {
      nodes: mockCustomAndFoundationalItems,
      pageInfo: mockPageInfo,
      __typename: 'AiCatalogCustomAndFoundationalItemConnectionType',
    },
  },
};

export const mockCatalogEmptyItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: [],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockAgentConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
  enabled: true,
  pinnedItemVersion: mockAgentPinnedVersion,
  flowTrigger: null,
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockItemConfigurationForGroup = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/4',
  enabled: true,
  serviceAccount: null,
  pinnedItemVersion: mockAgentGroupPinnedVersion,
  group: {
    id: 'gid://gitlab/Group/1',
    duoSettingsPath: '/groups/mock-group/-/settings/gitlab_duo/configuration',
  },
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockAiCatalogAgentResponse = {
  data: {
    aiCatalogItem: {
      ...mockAgent,
      isEnabledInManagedByProject: false,
      configurationForProject: mockAgentConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    },
  },
};

export const mockVersionProp = {
  isUpdateAvailable: false,
  activeVersionKey: 'latestVersion',
};

export const mockAiCatalogAgentNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogAgentDeleteResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCatalogAgentDeleteErrorResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: ['You do not have permission to delete this AI agent.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCreateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: [],
      item: mockBaseAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_CREATE,
    },
  },
};

export const mockCreateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdatedAgentVersion = {
  ...mockAgentVersion,
  updatedAt: '2025-08-22T14:30:00Z',
};

export const mockUpdateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: {
        ...mockAgent,
        latestVersion: mockUpdatedAgentVersion,
      },
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentNoChangeMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: mockAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentMetadataOnlyMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: {
        ...mockAgent,
        updatedAt: '2025-08-22T14:30:00Z',
      },
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdateAiCatalogItemConsumerSuccess = {
  data: {
    aiCatalogItemConsumerUpdate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
        pinnedVersionPrefix: '2.0.0',
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogItemConsumerError = {
  data: {
    aiCatalogItemConsumerUpdate: {
      errors: ['Some error'],
      itemConsumer: null,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE,
    },
  },
};

/* FLOWS */

export const mockFlowVersion = {
  ...mockBaseVersion,
  createdAt: '2024-01-15T10:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  definition: 'version: "v1"',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

export const mockFlowPinnedVersion = {
  ...mockFlowVersion,
  id: 'gid://gitlab/Ai::Catalog::ItemVersion/25',
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  definition: 'version: "v1"\n# pinned',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

export const mockFlowGroupPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/26' }),
  createdAt: '2025-08-19T14:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v0.8.0',
  versionName: '0.8.0',
  definition: 'version: "v1"\n# group pinned',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

const mockFlowFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/4',
  name: 'Test AI Flow 1',
  itemType: 'FLOW',
  description: 'A helpful AI flow for testing purposes',
  descriptionHtml: null,
  foundationalFlowReference: null,
  createdAt: '2024-01-15T10:30:00Z',
  public: true,
  visibility: 'PUBLIC',
  updatedAt: '2024-08-21T14:30:00Z',
  softDeleted: false,
  foundational: false,
  starCount: 0,
  starred: false,
  last30DayUsageCount: 0,
  verificationLevel: 'UNVERIFIED',
  latestVersion: mockBaseVersion,
  userPermissions: mockUserPermissions,
  __typename: TYPENAME_AI_CATALOG_FLOW,
  ...overrides,
});

export const mockFlow = mockFlowFactory({
  project: mockProjectWithGroup,
  latestVersion: mockFlowVersion,
});

export const mockFoundationalCatalogFlow = mockFlowFactory({
  project: mockProjectWithGroup,
  latestVersion: mockFlowVersion,
  foundational: true,
  foundationalFlowReference: 'code_review/v1',
  verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
});

export const mockBaseFlow = mockFlowFactory();

export const mockFlows = [
  mockFlowFactory({
    project: mockProjectWithNamespace,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/5',
    name: 'Test AI Flow 2',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    public: false,
    visibility: 'RESTRICTED',
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/6',
    name: 'Test AI Flow 3',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
  }),
];

const mockFlowVersionFactory = (overrides = {}) => ({
  ...mockVersionFactory(),
  createdBy: mockVersionCreatedByWithUsername,
  humanVersionName: 'v1.0.0',
  versionName: '1.0.0',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
  ...overrides,
});

export const mockBaseConfigs = {
  configurationForProject: {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
    enabled: true,
    pinnedItemVersion: mockFlowVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/30',
    }),
    __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
  },
  configurationForGroup: {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
    enabled: true,
    __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
  },
};

export const mockFlowsWithConfigs = [
  mockFlowFactory({
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/5',
    name: 'Test AI Flow 2',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/6',
    name: 'Test AI Flow 3',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
];

export const mockServiceAccount = {
  id: 'gid://gitlab/User/100',
  name: 'Fix pipeline/v1',
  createdAt: '2024-01-10T14:20:00Z',
  username: 'ai-fix-pipeline-v1-group-1',
  webPath: '/ai-fix-pipeline-v1-group-1',
  avatarUrl: 'https://example.com/avatar.png',
  __typename: TYPENAME_USER,
};

export const mockFlowTrigger = {
  id: 'gid://gitlab/Ai::FlowTrigger/73',
  eventTypes: [0],
  filter: {},
  user: mockServiceAccount,
  __typename: TYPENAME_AI_FLOW_TRIGGER,
};

export const mockFlowConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
  enabled: true,
  flowTrigger: mockFlowTrigger,
  pinnedItemVersion: mockFlowPinnedVersion,
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockFlowConfigurationForGroup = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/4',
  enabled: true,
  pinnedItemVersion: mockFlowGroupPinnedVersion,
  userPermissions: mockItemConsumerUserPermissions,
  serviceAccount: mockServiceAccount,
  group: {
    id: 'gid://gitlab/Group/1',
    duoSettingsPath: '/groups/mock-group/-/settings/gitlab_duo/configuration',
  },
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockCatalogFlowsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockFlows,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCreateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_CREATE,
    },
  },
};

export const mockCreateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdatedFlowVersion = {
  ...mockFlowVersion,
  updatedAt: '2025-08-22T14:30:00Z',
};

export const mockUpdateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: {
        ...mockFlow,
        latestVersion: mockUpdatedFlowVersion,
      },
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowNoChangeMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowMetadataOnlyMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: {
        ...mockFlow,
        updatedAt: '2025-08-22T14:30:00Z',
      },
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockAiCatalogFlowResponse = {
  data: {
    aiCatalogItem: {
      ...mockFlow,
      isEnabledInManagedByProject: false,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockFlowConfigurationForGroup,
    },
  },
};

export const mockAiCatalogFlowNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogFlowDeleteResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

export const mockCatalogFlowDeleteErrorResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: ['You do not have permission to delete this AI flow.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

/* THIRD-PARTY FLOWS */

export const mockThirdPartyFlowVersion = {
  ...mockBaseVersion,
  createdAt: '2025-08-21T14:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  definition: '---\\nimage: node:22\\ncommands:\\n- ls\\ninjectGatewayToken: true\\n',
  __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION,
};

export const mockThirdPartyFlowPinnedVersion = {
  ...mockBaseVersion,
  createdAt: '2025-08-20T14:30:00Z',
  createdBy: mockCreatedByUser,
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  definition: '---\\nimage: node:22\\ncommands:\\n- ls\\ninjectGatewayToken: true\\npinned',
  __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION,
};

export const mockThirdPartyFlowConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
  flowTrigger: mockFlowTrigger,
  pinnedItemVersion: mockThirdPartyFlowPinnedVersion,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

const mockThirdPartyFlowFactory = (overrides = {}) => ({
  ...mockFlowFactory(overrides),
  itemType: 'THIRD_PARTY_FLOW',
});

export const mockThirdPartyFlow = mockThirdPartyFlowFactory({
  project: mockProjectWithNamespace,
  latestVersion: mockThirdPartyFlowVersion,
});

export const mockCreateAiCatalogThirdPartyFlowSuccessMutation = {
  data: {
    aiCatalogThirdPartyFlowCreate: {
      errors: [],
      item: mockThirdPartyFlow,
      __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_CREATE,
    },
  },
};

export const mockUpdateAiCatalogThirdPartyFlowSuccessMutation = {
  data: {
    aiCatalogThirdPartyFlowUpdate: {
      errors: [],
      item: mockThirdPartyFlow,
      __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_UPDATE,
    },
  },
};

/* ITEM CONSUMERS */

export const mockBaseItemConsumer = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockConfiguredItemsEmptyResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessProjectResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        webPath: '/gitlab-org/test-project/-/automate/agents/1',
        project: {
          id: 'gid://gitlab/Project/1',
          name: 'Test',
        },
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Test',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse = {
  data: {
    aiCatalogItemConsumerBulkCreate: {
      errors: [],
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessGroupResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        webPath: '/groups/group-1/-/automate/agents/1',
        project: null,
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Test',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessFlowGroupResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        webPath: '/groups/group-1/-/automate/flows/4',
        project: null,
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Test',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateErrorResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: ['Item already configured.'],
      itemConsumer: null,
    },
  },
};

export const mockAiCatalogItemConsumerBulkCreateErrorResponse = {
  data: {
    aiCatalogItemConsumerBulkCreate: {
      errors: ['Item already configured.'],
    },
  },
};

export const mockAiCatalogItemConsumerDeleteResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockAiCatalogItemConsumerDeleteErrorResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: ['You do not have permission to disable this item.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockProjectsMaintainerResponse = {
  data: {
    projects: {
      nodes: [
        {
          id: 'gid://gitlab/Project/1000000',
          __typename: TYPENAME_PROJECT,
        },
      ],
      __typename: 'ProjectConnection',
    },
  },
};

export const mockReportAiCatalogItemSuccessMutation = {
  data: {
    aiCatalogItemReport: {
      errors: [],
      __typename: TYPENAME_AI_CATALOG_ITEM_REPORT,
    },
  },
};

export const mockReportAiCatalogItemErrorMutation = {
  data: {
    aiCatalogItemReport: {
      errors: [
        "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
      ],
      __typename: TYPENAME_AI_CATALOG_ITEM_REPORT,
    },
  },
};

export const mockAiCatalogItemStarSuccessMutation = {
  data: {
    aiCatalogItemStar: {
      starCount: 5,
      errors: [],
      __typename: TYPENAME_AI_CATALOG_ITEM_STAR,
    },
  },
};

export const mockAiCatalogItemStarErrorMutation = {
  data: {
    aiCatalogItemStar: {
      starCount: 0,
      errors: ['Star toggle failed'],
      __typename: TYPENAME_AI_CATALOG_ITEM_STAR,
    },
  },
};

/* SERVICE ACCOUNT PROJECT MEMBERSHIPS */
const accessLevels = ['Guest', 'Developer', 'Maintainer', 'Owner'];

const createProjectMemberships = (startAt = 0) =>
  Array.from({ length: 20 }, (_, i) => {
    const id = startAt + i + 1;
    return {
      accessLevel: {
        humanAccess: accessLevels[Math.floor(Math.random() * accessLevels.length)],
      },
      createdAt: new Date(
        2024,
        Math.floor(Math.random() * 12),
        Math.floor(Math.random() * 28) + 1,
      ).toISOString(),
      id: `gid://gitlab/ProjectMember/${id}`,
      project: {
        id: `gid://gitlab/Project/${id}`,
        nameWithNamespace: `Group / Project ${id}`,
        webUrl: `https://gitlab.com/project-${id}`,
      },
    };
  });

export const mockServiceAccountProjectMembershipsResponse = {
  data: {
    user: {
      id: 'gid://gitlab/User/100',
      projectMemberships: {
        nodes: createProjectMemberships(),
        pageInfo: mockPageInfo,
      },
    },
  },
};

/* MCP SERVERS */
export const mockMcpServer = {
  id: 'gid://gitlab/Ai::Catalog::McpServer/1',
  name: 'Test MCP Server',
  description: 'A test MCP server',
  url: 'https://example.com/mcp',
  homepageUrl: 'https://example.com',
  transport: 'HTTP',
  authType: 'OAUTH',
  oauthClientId: 'client-id',
  createdAt: '2024-01-15T10:30:00Z',
  updatedAt: '2024-01-15T10:30:00Z',
  __typename: TYPENAME_AI_CATALOG_MCP_SERVER,
};

export const mockMcpServerListItem = {
  id: 'gid://gitlab/Ai::Catalog::McpServer/1',
  name: 'Test MCP Server',
  description: 'A test MCP server description',
  url: 'https://example.com/mcp',
  transport: 'HTTP',
  authType: 'OAUTH',
  __typename: TYPENAME_AI_CATALOG_MCP_SERVER,
};

export const mockCreateMcpServerSuccessMutation = {
  data: {
    aiCatalogMcpServerCreate: {
      errors: [],
      mcpServer: mockMcpServer,
      __typename: TYPENAME_AI_CATALOG_MCP_SERVER_CREATE,
    },
  },
};

export const mockCreateMcpServerErrorMutation = {
  data: {
    aiCatalogMcpServerCreate: {
      errors: ['Some error'],
      mcpServer: null,
      __typename: TYPENAME_AI_CATALOG_MCP_SERVER_CREATE,
    },
  },
};

export const mockUpdateMcpServerSuccessMutation = {
  data: {
    aiCatalogMcpServerUpdate: {
      errors: [],
      mcpServer: mockMcpServer,
      __typename: TYPENAME_AI_CATALOG_MCP_SERVER_UPDATE,
    },
  },
};

export const mockUpdateMcpServerErrorMutation = {
  data: {
    aiCatalogMcpServerUpdate: {
      errors: ['Some error'],
      mcpServer: null,
      __typename: TYPENAME_AI_CATALOG_MCP_SERVER_UPDATE,
    },
  },
};

export const defaultDuoSettings = {
  duoSettings: {
    duoCustomAgentsEnabled: true,
    duoCustomFlowsEnabled: true,
    duoExternalAgentsEnabled: true,
    duoSettingsPath: '/groups/gitlab-duo/-/edit#js-gitlab-duo-settings',
  },
};
