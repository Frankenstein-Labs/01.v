export const makeVersion = (overrides = {}) => ({
  id: 'v-1',
  name: 'v1.0.0',
  digest: 'sha256:abc123def456',
  reference: 'registry.example.com/image:v1',
  createdAt: '2024-06-01T12:00:00Z',
  ...overrides,
});

export const makeArtifactSource = (overrides = {}) => ({
  id: 'source-1',
  sourceRef: 'registry.example.com/api-server',
  sourceConfig: '{}',
  versions: {
    nodes: [makeVersion()],
  },
  ...overrides,
});

export const makeEnvironment = (overrides = {}) => ({
  id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/1',
  name: 'prod-eu-west-1',
  tier: 'PRODUCTION',
  version: 'v1.2.3',
  health: 'HEALTHY',
  ...overrides,
});

export const makeCdRolloutEnvironment = (overrides = {}) => ({
  __typename: 'CdRolloutEnvironment',
  id: 'gid://gitlab/Cd::RolloutEnvironment/1',
  finishedAt: '2026-07-01T10:00:00Z',
  rollout: {
    __typename: 'CdRollout',
    id: 'gid://gitlab/Cd::Rollout/1',
    versionSet: {
      __typename: 'CdVersionSet',
      id: 'gid://gitlab/Cd::VersionSet/1',
      name: 'v2.4.1',
    },
    rolloutTransitions: {
      __typename: 'CdRolloutTransitionConnection',
      nodes: [
        {
          __typename: 'CdRolloutTransition',
          id: 'gid://gitlab/Cd::RolloutTransition/1',
          principalUser: {
            __typename: 'UserCore',
            id: 'gid://gitlab/User/1',
            username: 'jdoe',
          },
        },
      ],
    },
  },
  ...overrides,
});

export const makeCdEnvironmentDriverBinding = (overrides = {}) => ({
  __typename: 'CdEnvironmentDriverBinding',
  id: 'gid://gitlab/Cd::EnvironmentDriverBinding/1',
  version: 1,
  // Matches production-agent in buildDefaultAvailableAgentsQueryResponse, which is how the
  // card resolves a name for it.
  driverConfig: { cluster_agent_id: '1' },
  ...overrides,
});

export const makeCdServiceEnvironmentHealth = (overrides = {}) => ({
  __typename: 'CdServiceEnvironmentHealth',
  id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/1',
  health: 'HEALTHY',
  ...overrides,
});

export const makeCdEnvironment = (overrides = {}) => ({
  __typename: 'CdEnvironment',
  id: 'gid://gitlab/Cd::Environment/1',
  name: 'prod-eu-west-1',
  tier: 'PRODUCTION',
  applicationsCount: 5,
  serviceEnvironmentHealths: {
    __typename: 'CdServiceEnvironmentHealthConnection',
    nodes: [makeCdServiceEnvironmentHealth()],
  },
  environmentDriverBindings: {
    __typename: 'CdEnvironmentDriverBindingConnection',
    nodes: [makeCdEnvironmentDriverBinding()],
  },
  rolloutEnvironments: {
    __typename: 'CdRolloutEnvironmentConnection',
    nodes: [makeCdRolloutEnvironment()],
  },
  ...overrides,
});

export const makeCdApplicationLink = (overrides = {}) => ({
  __typename: 'CdApplicationLink',
  id: 'gid://gitlab/Cd::ApplicationLink/1',
  name: 'Payments runbook',
  url: 'https://runbooks.example.com/payments',
  linkType: 'RUNBOOK',
  ...overrides,
});

export const buildApplicationLinksResponse = (
  links = [makeCdApplicationLink()],
  pageInfo = {},
) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        __typename: 'CdApplication',
        id: 'gid://gitlab/Cd::Application/5',
        links: {
          __typename: 'CdApplicationLinkConnection',
          nodes: links,
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            ...pageInfo,
          },
        },
      },
    },
  },
});

export const makeService = (overrides = {}) => ({
  id: 'gid://gitlab/Cd::Service/1',
  name: 'api-server',
  serviceEnvironmentHealths: {
    nodes: [
      {
        id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/1',
        health: 'HEALTHY',
        environment: {
          id: 'gid://gitlab/Cd::Environment/1',
          name: 'prod-eu-west-1',
          tier: 'PRODUCTION',
        },
        deployedVersions: { nodes: [{ id: 'gid://gitlab/Cd::Version/1', name: 'v3.4.2' }] },
      },
    ],
  },
  lastDeployedAt: '2024-06-10T08:00:00Z',
  artifactSources: {
    nodes: [makeArtifactSource()],
  },
  ...overrides,
});

export const makeApplication = (overrides = {}) => ({
  id: 'gid://gitlab/Cd::Application/5',
  name: 'My Application',
  description: 'An application',
  updatedAt: '2024-06-01T00:00:00Z',
  health: 'DEGRADED',
  lastDeployedAt: '2024-06-01T00:00:00Z',
  environments: { count: 2, nodes: [] },
  services: {
    count: 2,
    nodes: [
      makeService({ id: 'gid://gitlab/Cd::Service/10', name: 'api-server' }),
      makeService({ id: 'gid://gitlab/Cd::Service/20', name: 'worker' }),
    ],
  },
  versionSets: {
    nodes: [
      {
        id: 'gid://gitlab/Cd::VersionSet/1',
        name: 'v1_1_0',
        createdAt: '2024-06-01T00:00:00Z',
        rollouts: { nodes: [{ id: 'gid://gitlab/Cd::Rollout/1', iid: 1 }] },
        latestRollout: {
          nodes: [
            {
              id: 'gid://gitlab/Cd::Rollout/1',
              state: 'IN_PROGRESS',
              rolloutEnvironments: { nodes: [] },
            },
          ],
        },
        versionSetEntries: {
          count: 2,
          nodes: [
            {
              service: { id: 'gid://gitlab/Cd::Service/10', name: 'api-server' },
              version: { id: 'gid://gitlab/Cd::Version/1', name: 'v2_4_1' },
            },
            {
              service: { id: 'gid://gitlab/Cd::Service/20', name: 'worker' },
              version: { id: 'gid://gitlab/Cd::Version/2', name: 'v1_9_0' },
            },
          ],
        },
      },
      {
        id: 'gid://gitlab/Cd::VersionSet/2',
        name: 'v1_0_0',
        createdAt: '2024-05-01T00:00:00Z',
        rollouts: { nodes: [{ id: 'gid://gitlab/Cd::Rollout/2', iid: 2 }] },
        latestRollout: {
          nodes: [
            {
              id: 'gid://gitlab/Cd::Rollout/2',
              state: 'COMPLETED',
              rolloutEnvironments: { nodes: [] },
            },
          ],
        },
        versionSetEntries: {
          count: 1,
          nodes: [
            {
              service: { id: 'gid://gitlab/Cd::Service/10', name: 'api-server' },
              version: { id: 'gid://gitlab/Cd::Version/3', name: 'v2_3_0' },
            },
          ],
        },
      },
    ],
  },
  ...overrides,
});

export const buildApplicationQueryResponse = (application = makeApplication()) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organization/1',
      cdApplication: application,
    },
  },
});

export const buildApplicationServicesResponse = (
  application = makeApplication(),
  pageInfo = {},
) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        id: application?.id ?? null,
        services: {
          ...(application?.services ?? { nodes: [] }),
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            ...pageInfo,
          },
        },
      },
    },
  },
});

export const buildApplicationReleasesResponse = (
  application = makeApplication(),
  pageInfo = {},
) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        id: application?.id ?? null,
        versionSets: {
          ...(application?.versionSets ?? { nodes: [] }),
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            ...pageInfo,
          },
        },
      },
    },
  },
});

export const buildApplicationDeploymentsResponse = (
  application = makeApplication(),
  pageInfo = {},
) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        id: application?.id ?? null,
        environments: application?.environments ?? { nodes: [] },
        rollouts: {
          ...(application?.rollouts ?? { nodes: [] }),
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            ...pageInfo,
          },
        },
      },
    },
  },
});

export const buildVersionSetQueryResponse = (versionSet) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organization/1',
      cdVersionSet: versionSet ?? null,
    },
  },
});

export const buildQueryResponse = (cdEnvironmentTiers) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organizations::Organization/1',
      cdEnvironmentTiers,
    },
  },
});

export const buildAvailableAgentsQueryResponse = (nodes) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organizations::Organization/1',
      cdAvailableAgents: {
        __typename: 'ClusterAgentConnection',
        nodes,
      },
    },
  },
});

export const defaultAvailableAgents = [
  { __typename: 'ClusterAgent', id: 'gid://gitlab/Clusters::Agent/1', name: 'production-agent' },
  { __typename: 'ClusterAgent', id: 'gid://gitlab/Clusters::Agent/2', name: 'staging-agent' },
];

export const buildDefaultAvailableAgentsQueryResponse = () =>
  buildAvailableAgentsQueryResponse(defaultAvailableAgents);

export const mockCdEnvironments = [
  makeCdEnvironment(),
  makeCdEnvironment({
    id: 'gid://gitlab/Cd::Environment/2',
    name: 'staging-us-east-1',
    tier: 'STAGING',
  }),
];

export const mockCdEnvironmentsNextPage = [
  makeCdEnvironment({
    id: 'gid://gitlab/Cd::Environment/3',
    name: 'qa-eu-west-2',
    tier: 'QA',
  }),
];

export const buildEnvironmentsQueryResponse = (nodes = [], pageInfo = {}) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organizations::Organization/1',
      cdEnvironments: {
        __typename: 'CdEnvironmentConnection',
        nodes,
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          ...pageInfo,
        },
      },
    },
  },
});

export const makeServiceHealthNode = ({ health, versionId = '1', versionName = 'v1-0-0' }) => ({
  __typename: 'CdServiceEnvironmentHealth',
  id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/1',
  health,
  environment: {
    __typename: 'CdEnvironment',
    id: 'gid://gitlab/Cd::Environment/1',
    name: 'prod-eu-west-1',
    tier: 'PRODUCTION',
  },
  deployedVersions: {
    __typename: 'CdVersionConnection',
    nodes: [
      { __typename: 'CdVersion', id: `gid://gitlab/Cd::Version/${versionId}`, name: versionName },
    ],
  },
});

export const buildServiceSubscriptionResponse = (health) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        __typename: 'CdApplication',
        id: 'gid://gitlab/Cd::Application/5',
        name: 'My Application',
        description: null,
        updatedAt: '2024-06-01T00:00:00Z',
        services: {
          count: 1,
          __typename: 'CdServiceConnection',
          nodes: [
            {
              __typename: 'CdService',
              id: 'gid://gitlab/Cd::Service/10',
              name: 'api-server',
              lastDeployedAt: '2024-06-10T08:00:00Z',
              serviceEnvironmentHealths: {
                __typename: 'CdServiceEnvironmentHealthConnection',
                nodes: [makeServiceHealthNode({ health })],
              },
            },
          ],
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
});

export const buildPushedService = (node) => ({
  __typename: 'CdService',
  id: 'gid://gitlab/Cd::Service/10',
  lastDeployedAt: '2024-06-10T08:00:00Z',
  serviceEnvironmentHealths: {
    __typename: 'CdServiceEnvironmentHealthConnection',
    nodes: [makeServiceHealthNode(node)],
  },
});

const deploymentEnvironment = {
  __typename: 'CdEnvironment',
  id: 'gid://gitlab/Cd::Environment/1',
  name: 'production',
  tier: 'PRODUCTION',
};

const otherDeploymentEnvironment = {
  __typename: 'CdEnvironment',
  id: 'gid://gitlab/Cd::Environment/2',
  name: 'staging',
  tier: 'STAGING',
};

export const buildDeploymentSubscriptionResponse = (
  rolloutState,
  rolloutEnvironmentState = rolloutState,
) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: 'gid://gitlab/Organization/1',
      cdApplication: {
        __typename: 'CdApplication',
        id: 'gid://gitlab/Cd::Application/5',
        name: 'My Application',
        description: null,
        updatedAt: '2024-06-01T00:00:00Z',
        health: 'HEALTHY',
        lastDeployedAt: '2024-06-01T00:00:00Z',
        services: { __typename: 'CdServiceConnection', count: 0, nodes: [] },
        environments: {
          __typename: 'CdEnvironmentConnection',
          count: 2,
          nodes: [deploymentEnvironment, otherDeploymentEnvironment],
        },
        rollouts: {
          __typename: 'CdRolloutConnection',
          nodes: [
            {
              __typename: 'CdRollout',
              id: 'gid://gitlab/Cd::Rollout/23',
              iid: 23,
              state: rolloutState,
              createdAt: '2024-06-01T00:00:00Z',
              versionSet: {
                __typename: 'CdVersionSet',
                id: 'gid://gitlab/Cd::VersionSet/20',
                name: 'v1_1_0',
              },
              rolloutEnvironments: {
                __typename: 'CdRolloutEnvironmentConnection',
                nodes: [
                  {
                    __typename: 'CdRolloutEnvironment',
                    id: 'gid://gitlab/Cd::RolloutEnvironment/8',
                    state: rolloutEnvironmentState,
                    environment: deploymentEnvironment,
                  },
                  {
                    __typename: 'CdRolloutEnvironment',
                    id: 'gid://gitlab/Cd::RolloutEnvironment/9',
                    state: 'PENDING',
                    environment: otherDeploymentEnvironment,
                  },
                ],
              },
            },
          ],
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
});

export const buildPushedDeployment = (rolloutState, rolloutEnvironmentState = rolloutState) => ({
  __typename: 'CdDeployment',
  id: 'gid://gitlab/Cd::Deployment/7',
  rolloutEnvironment: {
    __typename: 'CdRolloutEnvironment',
    id: 'gid://gitlab/Cd::RolloutEnvironment/8',
    state: rolloutEnvironmentState,
    rollout: { __typename: 'CdRollout', id: 'gid://gitlab/Cd::Rollout/23', state: rolloutState },
  },
});
