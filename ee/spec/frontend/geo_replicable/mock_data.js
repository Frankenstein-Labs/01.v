import { TOKEN_TYPES } from 'ee/geo_replicable/constants';

export const MOCK_REPLICABLE_TYPES = [
  {
    titlePlural: 'Design Management Repositories',
    namePlural: 'design_management_repositories',
    graphqlRegistryClass: 'DesignManagementRepositoryRegistry',
    graphqlFieldName: 'designManagementRepositoryRegistries',
    graphqlRegistryIdType: 'DesignManagementRegistryId',
    graphqlMutationRegistryClass: 'DESIGN_MANAGEMENT_REPOSITORY_REGISTRY',
    modelClassName: 'Designs',
    verificationEnabled: true,
  },
  {
    titlePlural: 'Project Repositories',
    namePlural: 'project_repositories',
    graphqlRegistryClass: 'ProjectRepositoryRegistry',
    graphqlFieldName: 'projectRepositoryRegistries',
    graphqlRegistryIdType: 'ProjectRepositoryRegistryId',
    graphqlMutationRegistryClass: 'PROJECT_REPOSITORY_REGISTRY',
    modelClassName: 'Projects',
    verificationEnabled: true,
  },
  {
    titlePlural: 'Package Files',
    namePlural: 'package_files',
    graphqlRegistryClass: 'PackageFileRegistry',
    graphqlFieldName: 'packageFileRegistries',
    graphqlRegistryIdType: 'PackageFileRegistryId',
    graphqlMutationRegistryClass: 'PACKAGE_FILE_REGISTRY',
    modelClassName: 'PackageFiles',
    verificationEnabled: false,
  },
];

export const MOCK_REPLICABLE_CLASS = MOCK_REPLICABLE_TYPES[0];

export const MOCK_REPLICABLE_TYPE = MOCK_REPLICABLE_TYPES[0].namePlural;

export const MOCK_GRAPHQL_REGISTRY = MOCK_REPLICABLE_TYPES[0].graphqlFieldName;

export const MOCK_GRAPHQL_REGISTRY_CLASS = MOCK_REPLICABLE_TYPES[0].graphqlRegistryClass;

export const MOCK_BASIC_GRAPHQL_DATA = [
  {
    id: 'gid://gitlab/Geo::MockRegistry/1',
    modelRecordId: 1,
    state: 'PENDING',
    verificationState: 'SUCCEEDED',
    lastSyncedAt: new Date().toString(),
    verifiedAt: new Date().toString(),
    lastSyncFailure: null,
    verificationFailure: null,
    retryCount: 0,
    retryAt: null,
    createdAt: new Date().toString(),
  },
  {
    id: 'gid://gitlab/Geo::MockRegistry/2',
    modelRecordId: 2,
    state: 'SYNCED',
    verificationState: 'FAILED',
    lastSyncedAt: null,
    verifiedAt: null,
    lastSyncFailure: null,
    verificationFailure: null,
    retryCount: 0,
    retryAt: null,
    createdAt: new Date().toString(),
  },
  {
    id: 'gid://gitlab/Geo::MockRegistry/3',
    modelRecordId: 3,
    state: 'FAILED',
    verificationState: 'FAILED',
    lastSyncedAt: new Date().toString(),
    verifiedAt: new Date().toString(),
    lastSyncFailure: 'There was a sync failure',
    verificationFailure: 'There was a verification failure',
    retryCount: 1,
    retryAt: new Date().toString(),
    createdAt: new Date().toString(),
  },
];

export const MOCK_GRAPHQL_PAGINATION_DATA = {
  __typename: 'PageInfo',
  hasNextPage: true,
  hasPreviousPage: true,
  startCursor: 'abc123',
  endCursor: 'abc124',
};

// Query.geoNode to be renamed to Query.geoSite => https://gitlab.com/gitlab-org/gitlab/-/issues/396739
export const MOCK_BASIC_GRAPHQL_QUERY_RESPONSE = {
  geoNode: {
    [MOCK_GRAPHQL_REGISTRY]: {
      pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
      nodes: MOCK_BASIC_GRAPHQL_DATA,
    },
  },
};

export const MOCK_REPLICABLE_BASE_PATH = '/admin/geo/sites/2/replication/project_repositories';

export const MOCK_REPLICABLE_TYPE_FILTER = {
  type: TOKEN_TYPES.REPLICABLE_TYPE,
  value: 'project_repositories',
};

export const MOCK_REPLICATION_STATUS_FILTER = {
  type: TOKEN_TYPES.REPLICATION_STATUS,
  value: {
    data: 'synced',
  },
};

export const MOCK_VERIFICATION_STATUS_FILTER = {
  type: TOKEN_TYPES.VERIFICATION_STATUS,
  value: {
    data: 'succeeded',
  },
};
