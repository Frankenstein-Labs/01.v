export const mockUser = {
  id: 'gid://gitlab/User/1',
  name: 'Alice Smith',
  username: 'alice',
  avatarUrl: '/uploads/-/system/user/avatar/1/avatar.png',
  webPath: '/alice',
  __typename: 'UserCore',
};

export const mockArtifactNodes = [
  {
    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1908',
    workflowDefinition: 'false_positive_detection/v1',
    webPath: '/gitlab-org/security-scanner/-/automate/agent-sessions/1908',
    downloadPath: '/gitlab-org/security-scanner/-/security/agent_artifacts/1908/download',
    auditEventsCount: 4,
    workflowCreatedAt: '2026-03-05T22:14:17Z',
    project: {
      id: 'gid://gitlab/Project/278964',
      name: 'Security Scanner',
      webPath: '/gitlab-org/security-scanner',
      fullPath: 'gitlab-org/security-scanner',
      __typename: 'Project',
    },
    triggeredBy: mockUser,
    __typename: 'DuoWorkflowSessionArtifact',
  },
  {
    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1909',
    workflowDefinition: 'code_review/v1',
    webPath: '/gitlab-org/frontend-app/-/automate/agent-sessions/1909',
    downloadPath: '/gitlab-org/frontend-app/-/security/agent_artifacts/1909/download',
    auditEventsCount: 7,
    workflowCreatedAt: '2026-03-05T21:30:45Z',
    project: {
      id: 'gid://gitlab/Project/278965',
      name: 'Frontend App',
      webPath: '/gitlab-org/frontend-app',
      fullPath: 'gitlab-org/frontend-app',
      __typename: 'Project',
    },
    triggeredBy: mockUser,
    __typename: 'DuoWorkflowSessionArtifact',
  },
];

export const mockArtifactNodeNoWebPath = {
  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1910',
  workflowDefinition: 'code_review/v1',
  webPath: null,
  downloadPath: null,
  auditEventsCount: 2,
  workflowCreatedAt: '2026-03-06T10:00:00Z',
  project: null,
  triggeredBy: null,
  __typename: 'DuoWorkflowSessionArtifact',
};

export const mockPageInfo = {
  startCursor: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1908',
  endCursor: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1909',
  hasNextPage: true,
  hasPreviousPage: false,
  __typename: 'PageInfo',
};

export const mockAgentArtifactsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      duoWorkflowSessionArtifacts: {
        count: 2,
        nodes: mockArtifactNodes,
        pageInfo: mockPageInfo,
        __typename: 'DuoWorkflowSessionArtifactConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockProjectAgentArtifactsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      duoWorkflowSessionArtifacts: {
        count: 2,
        nodes: mockArtifactNodes,
        pageInfo: mockPageInfo,
        __typename: 'DuoWorkflowSessionArtifactConnection',
      },
      __typename: 'Project',
    },
  },
};

export const mockEmptyAgentArtifactsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      duoWorkflowSessionArtifacts: {
        count: 0,
        nodes: [],
        pageInfo: {
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
          __typename: 'PageInfo',
        },
        __typename: 'DuoWorkflowSessionArtifactConnection',
      },
      __typename: 'Group',
    },
  },
};
