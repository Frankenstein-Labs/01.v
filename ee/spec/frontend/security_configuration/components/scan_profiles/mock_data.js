import { SCAN_PROFILE_SCANNER_HEALTH_ACTIVE } from '~/security_configuration/constants';

export const mockScanner = {
  id: 'gid://gitlab/Security::ScanProfile/1',
  name: 'Secret Detection Profile',
  description: 'Detects secrets',
  scanType: 'SECRET_DETECTION',
  gitlabRecommended: true,
  triggers: ['GIT_PUSH_EVENT'],
  __typename: 'ScanProfileType',
};

export const mockScanner2 = {
  id: 'gid://gitlab/Security::ScanProfile/2',
  name: 'SAST Profile',
  description: 'Detects vulnerabilities in source code',
  scanType: 'SAST',
  gitlabRecommended: true,
  triggers: ['MERGE_REQUEST_PIPELINE'],
  __typename: 'ScanProfileType',
};

export const mockJobData = {
  name: 'dependency-scanner-name',
  status: SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  failureMessage: null,
  webPath: '/group/project/-/jobs/123',
  duration: 21,
  finishedAt: '2026-03-27T12:22:00Z',
  source: 'merge_request_event',
  trace: { htmlSummary: '<span>some trace</span>' },
  pipeline: {
    id: 'gid://gitlab/Ci::Pipeline/456',
    path: '/gitlab-org/gitlab/-/pipelines/456',
  },
};

// active, failed, warning, stale, unconfigured
export const mockStatus = {
  scanType: 'SECRET_DETECTION',
  id: mockScanner.id,
  status: 'ACTIVE',
  consecutiveFailureCount: 3,
  consecutiveSuccessCount: 5,
  lastScanAt: '2026-03-17T14:30:00Z',
  buildId: 'gid://gitlab/CommitStatus/123',
  scanProfile: {
    id: mockScanner.id,
    name: mockScanner.name,
    scanType: mockScanner.scanType,
  },
};

// group
export const mockAnalyzerStatus = {
  analyzerType: 'SECRET_DETECTION',
  success: 3,
  failure: 1,
  stale: 2,
  notConfigured: 6,
  totalProjectsCount: 10,
  updatedAt: '2026-04-14T00:00:00Z',
};

export const mockSecurityPostureCounters = {
  withScanners: 7,
  withFailures: 2,
  withStale: 4,
};

// project
export const mockProjectAnalyzerStatus = {
  analyzerType: 'SECRET_DETECTION',
  status: 'Active',
  source: null,
  updatedAt: '2026-04-14T00:00:00Z',
};

export const mockProject = {
  id: 'gid://gitlab/Project/1',
  name: 'My Project',
  fullPath: 'my-group/my-project',
  avatarUrl: null,
  group: {
    id: 'gid://gitlab/Group/1',
    name: 'My Group',
    webPath: '/my-group',
    __typename: 'Group',
  },
  securityConfigurationPath: '/my-group/my-project/-/security/configuration',
  securityScanProfiles: [mockScanner, mockScanner2],
  analyzerStatuses: [mockProjectAnalyzerStatus],
  scanProfileStatuses: [],
  securityAttributes: { __typename: 'SecurityAttributeConnection', nodes: [] },
};
