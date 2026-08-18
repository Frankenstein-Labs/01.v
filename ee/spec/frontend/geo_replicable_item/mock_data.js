export const MOCK_REPLICABLE_CLASS = {
  graphqlRegistryClass: 'Geo::MockRegistry',
  graphqlFieldName: 'testGraphqlFieldName',
  graphqlRegistryIdType: 'GeoMockRegistryID',
  modelClassName: 'MockModel',
  verificationEnabled: true,
};

export const MOCK_REPLICABLE_WITH_VERIFICATION = {
  id: 'gid://gitlab/Geo::MockRegistry/1',
  dataManagementDetailsPath: '/admin/data_management/mock_model/1',
  checksumMismatch: false,
  createdAt: '2025-01-01',
  lastSyncFailure: null,
  lastSyncedAt: '2025-01-01',
  missingOnPrimary: false,
  modelRecordId: 1,
  retryAt: null,
  retryCount: null,
  state: 'SYNCED',
  verificationChecksum: '1395a9bd59ff0e7d2207bd9cde6b67ee4a2f56fd',
  verificationChecksumMismatched: false,
  verificationFailure: null,
  verificationRetryAt: null,
  verificationRetryCount: null,
  verificationStartedAt: null,
  verificationState: 'SUCCEEDED',
  verifiedAt: '2025-01-01',
};

export const MOCK_REPLICABLE_WITHOUT_VERIFICATION = {
  id: 'gid://gitlab/Geo::MockRegistry/2',
  dataManagementDetailsPath: '/admin/data_management/mock_model/2',
  checksumMismatch: false,
  createdAt: '2025-01-01',
  lastSyncFailure: null,
  lastSyncedAt: '2025-01-01',
  missingOnPrimary: false,
  modelRecordId: 2,
  retryAt: null,
  retryCount: null,
  state: 'SYNCED',
};
