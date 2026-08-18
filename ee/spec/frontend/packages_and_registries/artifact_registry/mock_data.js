import { observable, resetObservable } from '~/lib/utils/observable';

export const BASE_PATH = '/o/gitlab-org/-/artifact_registry/acme/repositories';

export const SLUG = 'acme';

export const ORGANIZATION_GID = 'gid://gitlab/Organizations::Organization/1';

export const CLIENT_BASE_URL = 'https://artifact-registry.example.com';

// The cache keys ArtifactRegistryRepository on `name` (graphql/cache_config.js), so a
// normalized repository lands here.
export const REPOSITORY_CACHE_ID = 'ArtifactRegistryRepository:{"name":"my-repository"}';

// Deliberately not SLUG: the settings section reads the handle from the registry alone, so a
// handle equal to the route's slug would leave a section rendering the wrong one looking right.
export const REGISTRY_HANDLE = 'my-registry';

export const REGISTRY_CREATED_AT = '2026-08-06T12:00:00Z';

export const mockArtifactRegistry = (overrides = {}) => ({
  __typename: 'ArtifactRegistry',
  handle: REGISTRY_HANDLE,
  status: 'active',
  createdAt: REGISTRY_CREATED_AT,
  ...overrides,
});

// The counters are strings because they reach the browser through GraphQL's BigInt scalar.
export const mockRepository = {
  __typename: 'ArtifactRegistryRepository',
  name: 'my-repository',
  format: 'MAVEN',
  kind: 'HOSTED',
  visibility: 'PRIVATE',
  description: 'A hosted Maven repository',
  downloadsCount: '1234',
  sizeBytes: '2048',
  lastUpdatedAt: '2026-06-01T00:00:00Z',
};

// A repository nothing was ever published to: zero counters and a null lastUpdatedAt.
export const mockUntouchedRepository = {
  __typename: 'ArtifactRegistryRepository',
  name: 'container-images',
  format: 'DOCKER',
  kind: 'VIRTUAL',
  visibility: 'PRIVATE',
  description: null,
  downloadsCount: '0',
  sizeBytes: '0',
  lastUpdatedAt: null,
};

export const mockRepositories = [mockRepository, mockUntouchedRepository];

// Artifact Registry cursors are opaque (ADR-009): nothing may parse these, only hand them back.
export const FIRST_PAGE_END_CURSOR = 'eyJuYW1lIjoibXktcmVwb3NpdG9yeSJ9';

export const SECOND_PAGE_START_CURSOR = 'eyJuYW1lIjoiY29udGFpbmVyLWltYWdlcyJ9';

const mockPageInfo = (overrides = {}) => ({
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
  ...overrides,
});

export const mockRepositoryPage = {
  __typename: 'ArtifactRegistryRepositoryConnection',
  nodes: mockRepositories,
  pageInfo: mockPageInfo(),
};

export const mockEmptyRepositoryPage = {
  __typename: 'ArtifactRegistryRepositoryConnection',
  nodes: [],
  pageInfo: mockPageInfo(),
};

const ARTIFACT_IDS = {
  'payment-service': '01937b2e-0000-7000-8000-000000000001',
  'api-gateway': '01937b2e-0000-7000-8000-000000000002',
  'auth-service': '01937b2e-0000-7000-8000-000000000003',
  'helm-charts': '01937b2e-0000-7000-8000-000000000004',
  'com.company.payment:core': '01937b2e-0000-7000-8000-000000000005',
  '@company/payment-core': '01937b2e-0000-7000-8000-000000000006',
  'design-tokens': '01937b2e-0000-7000-8000-000000000007',
  '@company/design-system': '01937b2e-0000-7000-8000-000000000008',
};

const mockImage = (name) => ({
  __typename: 'ArtifactRegistryImage',
  id: ARTIFACT_IDS[name],
  name,
});

export const mockImagePage = {
  __typename: 'ArtifactRegistryImageConnection',
  nodes: [mockImage('payment-service'), mockImage('api-gateway')],
  pageInfo: mockPageInfo(),
};

// A pair of single-row pages, so which page is rendered is legible from the row itself.
export const mockFirstImagePage = {
  __typename: 'ArtifactRegistryImageConnection',
  nodes: [mockImage('payment-service')],
  pageInfo: mockPageInfo({ hasNextPage: true, endCursor: FIRST_PAGE_END_CURSOR }),
};

export const mockSecondImagePage = {
  __typename: 'ArtifactRegistryImageConnection',
  nodes: [mockImage('auth-service')],
  pageInfo: mockPageInfo({ hasPreviousPage: true, startCursor: SECOND_PAGE_START_CURSOR }),
};

const mockMavenPackage = (groupId, artifactId) => ({
  __typename: 'ArtifactRegistryMavenPackage',
  id: ARTIFACT_IDS[`${groupId}:${artifactId}`],
  groupId,
  artifactId,
});

const mockNpmPackage = ({ scope = null, name, versionsCount }) => ({
  __typename: 'ArtifactRegistryNpmPackage',
  id: ARTIFACT_IDS[scope ? `${scope}/${name}` : name],
  name,
  scope,
  versionsCount,
});

export const mockMavenPackagePage = {
  __typename: 'ArtifactRegistryPackageConnection',
  nodes: [mockMavenPackage('com.company.payment', 'core')],
  pageInfo: mockPageInfo(),
};

export const mockNpmPackagePage = {
  __typename: 'ArtifactRegistryPackageConnection',
  nodes: [
    mockNpmPackage({ scope: '@company', name: 'payment-core', versionsCount: 5 }),
    mockNpmPackage({ name: 'design-tokens', versionsCount: 12 }),
  ],
  pageInfo: mockPageInfo(),
};

export const mockEmptyImagePage = {
  __typename: 'ArtifactRegistryImageConnection',
  nodes: [],
  pageInfo: mockPageInfo(),
};

const VERSION_IDS = {
  '3.2.1': '01937b2e-0000-7000-8000-000000000101',
  '2.0.0': '01937b2e-0000-7000-8000-000000000102',
};

const mockVersion = (version, createdAt) => ({
  __typename: 'ArtifactRegistryVersion',
  id: VERSION_IDS[version],
  version,
  createdAt,
});

export const mockVersions = [
  mockVersion('3.2.1', '2026-06-10T00:00:00Z'),
  mockVersion('2.0.0', '2026-04-02T00:00:00Z'),
];

export const mockVersionPage = {
  __typename: 'ArtifactRegistryVersionConnection',
  nodes: mockVersions,
  pageInfo: mockPageInfo(),
};

export const mockEmptyVersionPage = {
  __typename: 'ArtifactRegistryVersionConnection',
  nodes: [],
  pageInfo: mockPageInfo(),
};

export const mockUser = {
  __typename: 'UserCore',
  id: 'gid://gitlab/User/1',
  name: 'Alex Turner',
  avatarUrl: '/uploads/-/system/user/avatar/1/avatar.png',
  webPath: '/alex-turner',
};

const ARTIFACT_CONNECTIONS = {
  DOCKER: { images: mockImagePage, packages: null },
  OCI: { images: mockImagePage, packages: null },
  MAVEN: { images: null, packages: mockMavenPackagePage },
  NPM: { images: null, packages: mockNpmPackagePage },
};

const DETAIL_FIELDS = {
  artifactsCount: '3',
  createdAt: '2026-05-12T09:24:00Z',
  createdBy: mockUser,
  updatedBy: mockUser,
};

export const mockDetailRepository = (format = 'MAVEN', overrides = {}) => ({
  ...mockRepository,
  ...DETAIL_FIELDS,
  format,
  ...ARTIFACT_CONNECTIONS[format],
  ...overrides,
});

const ARTIFACTS = {
  DOCKER: { image: mockImage('payment-service'), package: null },
  OCI: { image: mockImage('helm-charts'), package: null },
  MAVEN: { image: null, package: mockMavenPackage('com.company.payment', 'core') },
  NPM: { image: null, package: mockNpmPackage({ scope: '@company', name: 'design-system' }) },
};

export const ARTIFACT_ID_FOR = {
  DOCKER: ARTIFACT_IDS['payment-service'],
  OCI: ARTIFACT_IDS['helm-charts'],
  MAVEN: ARTIFACT_IDS['com.company.payment:core'],
  NPM: ARTIFACT_IDS['@company/design-system'],
};

export const ARTIFACT_DISPLAY_NAMES = {
  DOCKER: 'payment-service',
  OCI: 'helm-charts',
  MAVEN: 'com.company.payment:core',
  NPM: '@company/design-system',
};

// The repository the artifact read resolves: its identity and the format that decides which of
// the two artifact fields answers.
export const mockArtifactRepository = (format = 'MAVEN', overrides = {}) => ({
  __typename: 'ArtifactRegistryRepository',
  name: mockRepository.name,
  format,
  ...overrides,
});

// An image for the container formats and a package for the rest, with null for whichever the
// format does not hold.
export const mockRepositoryArtifacts = (format) => ARTIFACTS[format];

export const mockOrganizationHandler = () =>
  jest.fn().mockResolvedValue({
    data: {
      organization: {
        __typename: 'Organization',
        id: ORGANIZATION_GID,
      },
    },
  });

export const mockRepositoriesResponse = (connection) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: ORGANIZATION_GID,
      artifactRegistryRepositories: connection,
    },
  },
});

export const mockRepositoryResponse = (repository) => ({
  data: {
    organization: {
      __typename: 'Organization',
      id: ORGANIZATION_GID,
      artifactRegistryRepository: repository,
    },
  },
});

// The repository the create and update payloads select, which is also the field set the edit
// prefill reads.
export const mockWrittenRepository = (overrides = {}) => ({
  __typename: 'ArtifactRegistryRepository',
  name: mockRepository.name,
  format: mockRepository.format,
  kind: mockRepository.kind,
  visibility: mockRepository.visibility,
  description: mockRepository.description,
  ...overrides,
});

// A GraphQL response keys its data by the alias the document declares, which is why these
// carry `createRepository` rather than the schema's field name.
export const mockCreateRepositoryResponse = ({
  repository = mockWrittenRepository(),
  errors = [],
} = {}) => ({
  data: {
    createRepository: {
      __typename: 'ArtifactRegistryRepositoryCreatePayload',
      repository,
      errors,
    },
  },
});

export const mockUpdateRepositoryResponse = ({
  repository = mockWrittenRepository(),
  errors = [],
} = {}) => ({
  data: {
    updateRepository: {
      __typename: 'ArtifactRegistryRepositoryUpdatePayload',
      repository,
      errors,
    },
  },
});

export const mockDeleteRepositoryResponse = ({ errors = [] } = {}) => ({
  data: {
    deleteRepository: {
      __typename: 'ArtifactRegistryRepositoryDeletePayload',
      errors,
    },
  },
});

const BREADCRUMB_STATE_KEY = 'artifact_registry_breadcrumb';

export const createBreadCrumbState = () =>
  observable(BREADCRUMB_STATE_KEY, {
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

export const resetBreadCrumbState = () => resetObservable(BREADCRUMB_STATE_KEY);
