const mockProjects = [
  {
    __typename: 'Project',
    id: 'gid://gitlab/Project/19',
    name: 'security-reports-example',
    path: 'security-reports-example',
    fullPath: 'flightjs/security-reports-example',
    avatarUrl: null,
    webUrl: 'http://gdk.test:3000/flightjs/security-reports-example',
    updatedAt: '2025-01-01T09:55:10Z',
    secretPushProtectionEnabled: false,
    containerScanningForRegistryEnabled: false,
    securityAttributes: {
      nodes: [],
    },
    vulnerabilityStatistic: {
      critical: 10,
      high: 5,
      low: 4,
      info: 0,
      medium: 48,
      unknown: 7,
      updatedAt: '2025-01-01T00:00:00Z',
    },
    analyzerStatuses: [
      {
        status: 'SUCCESS',
        analyzerType: 'SAST',
        lastCall: '2025-01-01T00:00:00Z',
        buildId: 'gid://git/path/123',
        updatedAt: '2025-01-01T00:00:00Z',
      },
    ],
  },
  {
    __typename: 'Project',
    id: 'gid://gitlab/Project/7',
    name: 'Flight',
    path: 'Flight',
    fullPath: 'flightjs/Flight',
    avatarUrl: null,
    webUrl: 'http://gdk.test:3000/flightjs/Flight',
    updatedAt: '2025-01-01T09:55:10Z',
    secretPushProtectionEnabled: false,
    containerScanningForRegistryEnabled: false,
    securityAttributes: {
      nodes: [],
    },
    vulnerabilityStatistic: {
      critical: 10,
      high: 0,
      low: 0,
      info: 0,
      medium: 0,
      unknown: 0,
      updatedAt: '2025-01-01T00:00:00Z',
    },
    analyzerStatuses: [
      {
        status: 'FAILED',
        analyzerType: 'SAST',
        lastCall: '2025-01-01T10:20:14Z',
        buildId: 'gid://git/path/123',
        updatedAt: '2025-01-01T00:00:00Z',
      },
      {
        status: 'FAILED',
        analyzerType: 'SAST_ADVANCED',
        lastCall: '2025-01-01T10:20:14Z',
        updatedAt: '2025-01-01T00:00:00Z',
        buildId: 'gid://git/path/123',
      },
    ],
  },
];

const mockSubgroups = [
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/211',
    name: 'Test Subgroup',
    descendantGroupsCount: 0,
    projectsCount: 1,
    path: 'test-subgroup',
    fullPath: 'flightjs/test-subgroup',
    avatarUrl: '/avatar.png',
    webUrl: 'http://gdk.test:3000/groups/flightjs/test-subgroup',
    updatedAt: '2025-01-01T09:55:10Z',
    analyzerStatuses: [
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 0,
        failure: 1,
        stale: 2,
        notConfigured: 3,
        analyzerType: 'SAST',
        updatedAt: '2025-01-01T10:29:48Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 0,
        failure: 1,
        stale: 2,
        notConfigured: 3,
        analyzerType: 'SAST_ADVANCED',
        updatedAt: '2025-01-01T10:29:48Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 1,
        failure: 0,
        stale: 2,
        notConfigured: 3,
        analyzerType: 'SAST_IAC',
        updatedAt: '2025-01-01T10:29:48Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 1,
        failure: 0,
        stale: 2,
        notConfigured: 6,
        analyzerType: 'CONTAINER_SCANNING',
        updatedAt: '2025-06-25T07:05:06Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 1,
        failure: 0,
        stale: 2,
        notConfigured: 6,
        analyzerType: 'CONTAINER_SCANNING_FOR_REGISTRY',
        updatedAt: '2025-06-25T07:05:06Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 4,
        failure: 0,
        stale: 2,
        notConfigured: 3,
        analyzerType: 'SECRET_DETECTION_SECRET_PUSH_PROTECTION',
        updatedAt: '2025-06-25T07:07:51Z',
      },
      {
        __typename: 'AnalyzerGroupStatusType',
        success: 4,
        failure: 0,
        stale: 2,
        notConfigured: 3,
        analyzerType: 'SECRET_DETECTION',
        updatedAt: '2025-06-25T07:07:51Z',
      },
    ],
    vulnerabilityNamespaceStatistic: {
      critical: 10,
      high: 10,
      low: 10,
      info: 10,
      medium: 20,
      unknown: 20,
      updatedAt: '2025-01-01T00:00:00Z',
    },
  },
];

export const subgroupsAndProjects = {
  data: {
    group: {
      id: 'gid://gitlab/Group/33',
      projectsCount: 2,
      descendantGroupsCount: 1,
      avatarUrl: null,
      descendantGroups: {
        nodes: mockSubgroups,
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
      projects: {
        nodes: mockProjects,
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export { mockProjects, mockSubgroups };

export const namespaceSecurityProjectsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/33',
    },
    namespaceSecurityProjects: {
      edges: mockProjects.map((project) => ({ node: project })),
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
    },
  },
};

export const groupWithSubgroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/3',
      name: 'A group',
      fullPath: 'a-group',
      avatarUrl: 'a_group_avatar.png',
      descendantGroups: {
        edges: [
          {
            node: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/31',
              name: 'Subgroup with projects and subgroups',
              projectsCount: 3,
              descendantGroupsCount: 2,
              fullPath: 'a-group/subgroup-with-projects-and-subgroups',
            },
          },
          {
            node: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/32',
              name: 'Subgroup with projects',
              projectsCount: 2,
              descendantGroupsCount: 0,
              fullPath: 'a-group/subgroup-with-projects',
            },
          },
          {
            node: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/33',
              name: 'Subgroup with subgroups',
              projectsCount: 0,
              descendantGroupsCount: 3,
              fullPath: 'a-group/subgroup-with-subgroups',
            },
          },
          {
            node: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/34',
              name: 'Empty subgroup',
              projectsCount: 0,
              descendantGroupsCount: 0,
              fullPath: 'a-group/empty-subgroup',
            },
          },
        ],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: 'END_CURSOR',
        },
      },
    },
  },
};

export const groupWithoutSubgroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/4',
      name: 'B group',
      fullPath: 'b-group',
      avatarUrl: 'b_group_avatar.png',
      descendantGroups: {
        edges: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: 'END_CURSOR',
        },
      },
    },
  },
};

export const mockGroupAvatarAndParent = {
  name: 'group',
  avatarUrl: 'path/to/avatar',
  parent: {
    fullPath: 'path/to',
  },
};

export const mockAnalyzerFilter = { analyzerType: 'SAST_ADVANCED', status: 'NOT_CONFIGURED' };
export const mockVulnerabilityFilter = {
  severity: 'CRITICAL',
  operator: 'EQUAL_TO',
  count: 0,
};
export const mockAttributeFilter = {
  operator: 'IS_NOT_ONE_OF',
  attributes: ['gid://gitlab/Security::Attribute/3', 'gid://gitlab/Security::Attribute/4'],
};
