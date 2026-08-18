export const MOCK_NEW_SITE_URL = 'http://localhost:3000/admin/geo/sites/new';

export const MOCK_EMPTY_STATE_SVG = 'illustrations/empty-state/empty-geo-md.svg';

export const MOCK_UNSORTED_REPLICABLE_TYPES = [
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Repository',
    titlePlural: 'Repositories',
    name: 'repository',
    namePlural: 'repositories',
    dataManagementUrl: '/admin/data_management/repositories',
    replicationEnabled: true,
    verificationEnabled: true,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Design',
    titlePlural: 'Designs',
    name: 'design',
    namePlural: 'designs',
    dataManagementUrl: '/admin/data_management/designs',
    replicationEnabled: false,
    verificationEnabled: false,
  },
  {
    dataType: 'container_repository',
    dataTypeTitle: 'Container repository',
    dataTypeSortOrder: 2,
    title: 'Container repository',
    titlePlural: 'Container repositories',
    name: 'container_repository',
    namePlural: 'container_repositories',
    dataManagementUrl: '/admin/data_management/container_repositories',
    replicationEnabled: true,
    verificationEnabled: false,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Wiki',
    titlePlural: 'Wikis',
    name: 'wiki',
    namePlural: 'wikis',
    dataManagementUrl: '/admin/data_management/wikis',
    replicationEnabled: true,
    verificationEnabled: false,
  },
  {
    dataType: 'blob',
    dataTypeTitle: 'File',
    dataTypeSortOrder: 1,
    title: 'Package File',
    titlePlural: 'Package Files',
    name: 'package_file',
    namePlural: 'package_files',
    dataManagementUrl: '/admin/data_management/package_files',
    replicationEnabled: true,
    verificationEnabled: false,
  },
];

export const MOCK_SORTED_REPLICABLE_TYPES = [
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Design',
    titlePlural: 'Designs',
    name: 'design',
    namePlural: 'designs',
    dataManagementUrl: '/admin/data_management/designs',
    replicationEnabled: false,
    verificationEnabled: false,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Repository',
    titlePlural: 'Repositories',
    name: 'repository',
    namePlural: 'repositories',
    dataManagementUrl: '/admin/data_management/repositories',
    replicationEnabled: true,
    verificationEnabled: true,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    dataTypeSortOrder: 0,
    title: 'Wiki',
    titlePlural: 'Wikis',
    name: 'wiki',
    namePlural: 'wikis',
    dataManagementUrl: '/admin/data_management/wikis',
    replicationEnabled: true,
    verificationEnabled: false,
  },
  {
    dataType: 'blob',
    dataTypeTitle: 'File',
    dataTypeSortOrder: 1,
    title: 'Package File',
    titlePlural: 'Package Files',
    name: 'package_file',
    namePlural: 'package_files',
    dataManagementUrl: '/admin/data_management/package_files',
    replicationEnabled: true,
    verificationEnabled: false,
  },
  {
    dataType: 'container_repository',
    dataTypeTitle: 'Container repository',
    dataTypeSortOrder: 2,
    title: 'Container repository',
    titlePlural: 'Container repositories',
    name: 'container_repository',
    namePlural: 'container_repositories',
    dataManagementUrl: '/admin/data_management/container_repositories',
    replicationEnabled: true,
    verificationEnabled: false,
  },
];

export const MOCK_DATA_TYPES = [
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
  },
  {
    dataType: 'blob',
    dataTypeTitle: 'File',
  },
  {
    dataType: 'container_repository',
    dataTypeTitle: 'Container repository',
  },
];

// This const is very specific, it is a hard coded filtered information from MOCK_SITES
// Be sure if updating you follow the pattern else getters_spec.js will fail.
export const MOCK_VERIFICATION_INFO = [
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'designs',
    titlePlural: 'Designs',
    dataManagementUrl: '/admin/data_management/designs',
    verificationEnabled: false,
    values: null,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'repositories',
    titlePlural: 'Repositories',
    dataManagementUrl: '/admin/data_management/repositories',
    verificationEnabled: true,
    values: {
      total: 12,
      success: 12,
      failed: 0,
    },
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'wikis',
    titlePlural: 'Wikis',
    dataManagementUrl: '/admin/data_management/wikis',
    verificationEnabled: false,
    values: null,
  },
  {
    dataType: 'blob',
    dataTypeTitle: 'File',
    namePlural: 'package_files',
    titlePlural: 'Package Files',
    dataManagementUrl: '/admin/data_management/package_files',
    verificationEnabled: false,
    values: null,
  },
  {
    dataType: 'container_repository',
    dataTypeTitle: 'Container repository',
    namePlural: 'container_repositories',
    titlePlural: 'Container repositories',
    dataManagementUrl: '/admin/data_management/container_repositories',
    verificationEnabled: false,
    values: null,
  },
];

// This const is very specific, it is a hard coded filtered information from MOCK_SITES
// Be sure if updating you follow the pattern else getters_spec.js will fail.
export const MOCK_SECONDARY_SYNC_INFO = [
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'designs',
    titlePlural: 'Designs',
    replicationEnabled: false,
    values: null,
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'repositories',
    titlePlural: 'Repositories',
    replicationEnabled: true,
    values: {
      total: 12,
      success: 12,
      failed: 0,
    },
  },
  {
    dataType: 'repository',
    dataTypeTitle: 'Git',
    namePlural: 'wikis',
    titlePlural: 'Wikis',
    replicationEnabled: true,
    values: {
      total: 12,
      success: 6,
      failed: 6,
    },
  },
  {
    dataType: 'blob',
    dataTypeTitle: 'File',
    namePlural: 'package_files',
    titlePlural: 'Package Files',
    replicationEnabled: true,
    values: {
      total: 25,
      success: 25,
      failed: 0,
    },
  },
  {
    dataType: 'container_repository',
    dataTypeTitle: 'Container repository',
    namePlural: 'container_repositories',
    titlePlural: 'Container repositories',
    replicationEnabled: true,
    values: {
      total: 15,
      success: 10,
      failed: 5,
    },
  },
];

// This const is very specific, it is a hard coded camelCase version of MOCK_PRIMARY_SITE_RES and MOCK_PRIMARY_SITE_STATUSES_RES
// Be sure if updating you follow the pattern else actions_spec.js will fail.
export const MOCK_PRIMARY_SITE = {
  id: 1,
  name: 'Test Site 1',
  url: 'http://127.0.0.1:3001/',
  primary: true,
  enabled: true,
  current: true,
  geoNodeId: 1, // geo_node_id to be converted to geo_site_id in => https://gitlab.com/gitlab-org/gitlab/-/issues/369140
  healthStatus: 'Healthy',
  repositoriesCount: 12,
  repositoriesChecksumTotalCount: 12,
  repositoriesChecksummedCount: 12,
  repositoriesChecksumFailedCount: 0,
  replicationSlotsMaxRetainedWalBytes: 502658737,
  replicationSlotsCount: 1,
  replicationSlotsUsedCount: 0,
  version: '10.4.0-pre',
  revision: 'b93c51849b',
  webEditUrl: 'http://127.0.0.1:3001/admin/geo/sites/1',
};

// This const is very specific, it is a hard coded camelCase version of MOCK_SECONDARY_SITE_RES and MOCK_SECONDARY_SITE_STATUSES_RES
// Be sure if updating you follow the pattern else actions_spec.js will fail.
export const MOCK_SECONDARY_SITE = {
  id: 2,
  name: 'Test Site 2',
  url: 'http://127.0.0.1:3002/',
  primary: false,
  enabled: true,
  current: false,
  geoNodeId: 2, // geo_node_id to be converted to geo_site_id in => https://gitlab.com/gitlab-org/gitlab/-/issues/369140
  healthStatus: 'Healthy',
  repositoriesCount: 12,
  repositoriesFailedCount: 0,
  repositoriesSyncedCount: 12,
  repositoriesVerificationTotalCount: 12,
  repositoriesVerifiedCount: 12,
  repositoriesVerificationFailedCount: 0,
  wikisCount: 12,
  wikisFailedCount: 6,
  wikisSyncedCount: 6,
  designsCount: 12,
  designsFailedCount: 0,
  designsSyncedCount: 0,
  packageFilesCount: 25,
  packageFilesSyncedCount: 25,
  packageFilesFailedCount: 0,
  containerRepositoriesCount: 15,
  containerRepositoriesSyncedCount: 10,
  containerRepositoriesFailedCount: 5,
  dbReplicationLagSeconds: 0,
  lastEventId: 3,
  lastEventTimestamp: 1511255200,
  cursorLastEventId: 3,
  cursorLastEventTimestamp: 1511255200,
  version: '10.4.0-pre',
  revision: 'b93c51849b',
  storageShardsMatch: true,
  webGeoReplicationDetailsUrl: 'http://127.0.0.1:3002/admin/geo/sites/2/replication/lfs_objects',
};

export const MOCK_SITES = [MOCK_PRIMARY_SITE, MOCK_SECONDARY_SITE];

export const MOCK_PRIMARY_SITE_RES = {
  id: 1,
  name: 'Test Site 1',
  url: 'http://127.0.0.1:3001/',
  primary: true,
  enabled: true,
  current: true,
};

export const MOCK_SECONDARY_SITE_RES = {
  id: 2,
  name: 'Test Site 2',
  url: 'http://127.0.0.1:3002/',
  primary: false,
  enabled: true,
  current: false,
};

export const MOCK_SITES_RES = [MOCK_PRIMARY_SITE_RES, MOCK_SECONDARY_SITE_RES];

export const MOCK_PRIMARY_SITE_STATUSES_RES = {
  geo_node_id: 1, // geo_node_id to be converted to geo_site_id in => https://gitlab.com/gitlab-org/gitlab/-/issues/369140
  health_status: 'Healthy',
  repositories_count: 12,
  repositories_checksum_total_count: 12,
  repositories_checksummed_count: 12,
  repositories_checksum_failed_count: 0,
  replication_slots_max_retained_wal_bytes: 502658737,
  replication_slots_count: 1,
  replication_slots_used_count: 0,
  version: '10.4.0-pre',
  revision: 'b93c51849b',
  web_edit_url: 'http://127.0.0.1:3001/admin/geo/sites/1',
};

export const MOCK_SECONDARY_SITE_STATUSES_RES = {
  geo_node_id: 2, // geo_node_id to be converted to geo_site_id in => https://gitlab.com/gitlab-org/gitlab/-/issues/369140
  health_status: 'Healthy',
  repositories_count: 12,
  repositories_failed_count: 0,
  repositories_synced_count: 12,
  repositories_verification_total_count: 12,
  repositories_verified_count: 12,
  repositories_verification_failed_count: 0,
  wikis_count: 12,
  wikis_failed_count: 6,
  wikis_synced_count: 6,
  designs_count: 12,
  designs_failed_count: 0,
  designs_synced_count: 0,
  package_files_count: 25,
  package_files_synced_count: 25,
  package_files_failed_count: 0,
  container_repositories_count: 15,
  container_repositories_synced_count: 10,
  container_repositories_failed_count: 5,
  db_replication_lag_seconds: 0,
  last_event_id: 3,
  last_event_timestamp: 1511255200,
  cursor_last_event_id: 3,
  cursor_last_event_timestamp: 1511255200,
  version: '10.4.0-pre',
  revision: 'b93c51849b',
  storage_shards_match: true,
  web_geo_replication_details_url:
    'http://127.0.0.1:3002/admin/geo/sites/2/replication/lfs_objects',
};

export const MOCK_SITE_STATUSES_RES = [
  MOCK_PRIMARY_SITE_STATUSES_RES,
  MOCK_SECONDARY_SITE_STATUSES_RES,
];

export const MOCK_FILTER_SITES = [
  {
    name: 'healthy1',
    url: 'url/1',
    healthStatus: 'Healthy',
  },
  {
    name: 'healthy2',
    url: 'url/2',
    healthStatus: 'Healthy',
  },
  {
    name: 'unhealthy1',
    url: 'url/3',
    healthStatus: 'Unhealthy',
  },
  {
    name: 'disabled1',
    url: 'url/4',
    healthStatus: 'Disabled',
  },
  {
    name: 'offline1',
    url: 'url/5',
    healthStatus: 'Offline',
  },
  {
    name: 'unknown1',
    url: 'url/6',
    healthStatus: null,
  },
];

export const MOCK_NOT_CONFIGURED_EMPTY_STATE = {
  title: 'Discover GitLab Geo',
  description:
    'Help your team work faster from any location. GitLab Geo creates read-only mirrors of your instance to clone and fetch large repositories quicker.',
  showLearnMoreButton: true,
};

export const MOCK_NO_RESULTS_EMPTY_STATE = {
  title: 'No Geo site found',
  description: 'Edit your search and try again.',
  showLearnMoreButton: false,
};

export const MOCK_REPLICATION_COUNTS = [
  {
    dataType: 'type_1',
    dataTypeTitle: 'Type 1',
    sync: [{ total: 100, success: 100 }],
    verification: [{ total: 100, success: 100 }],
  },
  {
    dataType: 'type_2',
    dataTypeTitle: 'Type 2',
    sync: [{ total: 100, success: 0 }],
    verification: [{ total: 100, success: 0 }],
  },
];

export const GEO_SITE_W_DATA_FIXTURE = `<div id="js-geo-sites" data-new-site-url="admin/geo/sites/new" data-geo-sites-empty-state-svg="geo/sites/empty-state.svg" data-replicable-types="[]"></div>`;
