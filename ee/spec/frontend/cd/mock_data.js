export const cdApplicationId = 'gid://gitlab/Cd::Application/1';

export const mockServices = [
  {
    id: 'gid://gitlab/Cd::Service/1',
    name: 'payment-api',
    artifactSources: {
      nodes: [
        {
          id: 'gid://gitlab/Cd::ArtifactSource/1',
          sourceRef: 'registry.example.com/payment-api',
          versions: {
            nodes: [
              {
                id: 'gid://gitlab/Cd::Version/1',
                name: 'v1.0.0',
                createdAt: '2024-01-01T00:00:00Z',
              },
              {
                id: 'gid://gitlab/Cd::Version/2',
                name: 'v2.0.0',
                createdAt: '2024-03-01T00:00:00Z',
              },
            ],
          },
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Cd::Service/2',
    name: 'fraud-detector',
    artifactSources: {
      nodes: [
        {
          id: 'gid://gitlab/Cd::ArtifactSource/2',
          sourceRef: 'registry.example.com/fraud-detector',
          versions: {
            nodes: [
              {
                id: 'gid://gitlab/Cd::Version/3',
                name: 'v0.9.0',
                createdAt: '2024-02-01T00:00:00Z',
              },
            ],
          },
        },
      ],
    },
  },
];

export const serviceWithoutVersions = {
  id: 'gid://gitlab/Cd::Service/9',
  name: 'legacy-batch',
  artifactSources: { nodes: [] },
};

export const serviceWithEmptySource = {
  id: 'gid://gitlab/Cd::Service/8',
  name: 'notifications',
  artifactSources: {
    nodes: [
      {
        id: 'gid://gitlab/Cd::ArtifactSource/8',
        sourceRef: 'registry.example.com/notifications',
        versions: { nodes: [] },
      },
    ],
  },
};

export const serviceWithVersions = {
  id: 'gid://gitlab/Cd::Service/5',
  name: 'gateway',
  artifactSources: {
    nodes: [
      {
        id: 'gid://gitlab/Cd::ArtifactSource/5',
        sourceRef: 'registry.example.com/gateway',
        versions: {
          nodes: [
            { id: 'gid://gitlab/Cd::Version/10', name: 'v1', createdAt: '2024-05-01T00:00:00Z' },
            { id: 'gid://gitlab/Cd::Version/11', name: 'v2', createdAt: '2024-05-01T00:00:00Z' },
          ],
        },
      },
    ],
  },
};

export const serviceWithMultipleSources = {
  id: 'gid://gitlab/Cd::Service/7',
  name: 'checkout',
  artifactSources: {
    nodes: [
      {
        id: 'gid://gitlab/Cd::ArtifactSource/71',
        sourceRef: 'registry.example.com/checkout-amd64',
        versions: {
          nodes: [
            {
              id: 'gid://gitlab/Cd::Version/20',
              name: 'v1.0.0',
              createdAt: '2024-04-01T00:00:00Z',
            },
            {
              id: 'gid://gitlab/Cd::Version/21',
              name: 'v1.1.0',
              createdAt: '2024-06-01T00:00:00Z',
            },
          ],
        },
      },
      {
        id: 'gid://gitlab/Cd::ArtifactSource/72',
        sourceRef: 'registry.example.com/checkout-arm64',
        versions: {
          nodes: [
            {
              id: 'gid://gitlab/Cd::Version/22',
              name: 'v2.0.0',
              createdAt: '2024-05-01T00:00:00Z',
            },
          ],
        },
      },
    ],
  },
};

const DEFAULT_PAGE_INFO = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
};

const defaultPresetVersionIds = ['gid://gitlab/Cd::Version/1', 'gid://gitlab/Cd::Version/3'];

const buildVersionSets = (presetVersionIds) =>
  presetVersionIds.length
    ? [
        {
          id: 'gid://gitlab/Cd::VersionSet/1',
          versionSetEntries: {
            nodes: presetVersionIds.map((versionId, index) => ({
              id: `gid://gitlab/Cd::VersionSetEntry/${index + 1}`,
              version: { id: versionId, name: `preset-${index + 1}` },
            })),
          },
        },
      ]
    : [];

export const cdApplicationServicesResponse = (
  services = mockServices,
  { pageInfo = {}, presetVersionIds = defaultPresetVersionIds } = {},
) => ({
  data: {
    organization: {
      id: 'gid://gitlab/Organizations::Organization/1',
      cdApplication: {
        id: cdApplicationId,
        services: {
          nodes: services,
          pageInfo: { ...DEFAULT_PAGE_INFO, ...pageInfo },
        },
        versionSets: {
          nodes: buildVersionSets(presetVersionIds),
        },
      },
    },
  },
});
