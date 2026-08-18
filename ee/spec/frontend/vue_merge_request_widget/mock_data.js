import mockData, { mockStore } from 'jest/vue_merge_request_widget/mock_data';

export default {
  ...mockData,
  can_read_vulnerabilities: true,
  enabled_reports: {
    sast: false,
    container_scanning: false,
    dast: false,
    dependency_scanning: false,
    license_management: false,
    secret_detection: false,
  },
  discover_project_security_path: '/discover_project_security',
  merge_immediately_docs_path: '/merge_immediately_docs',
  saml_approval_path: '/group/saml_sso_path',
};

// Browser Performance Testing
export const headBrowserPerformance = [
  {
    subject: '/some/path',
    metrics: [
      {
        name: 'Total Score',
        value: 80,
        desiredSize: 'larger',
      },
      {
        name: 'Requests',
        value: 30,
        desiredSize: 'smaller',
      },
      {
        name: 'Speed Index',
        value: 1155,
        desiredSize: 'smaller',
      },
      {
        name: 'Transfer Size (KB)',
        value: '1070.1',
        desiredSize: 'smaller',
      },
    ],
  },
];

export const baseBrowserPerformance = [
  {
    subject: '/some/path',
    metrics: [
      {
        name: 'Total Score',
        value: 82,
        desiredSize: 'larger',
      },
      {
        name: 'Requests',
        value: 30,
        desiredSize: 'smaller',
      },
      {
        name: 'Speed Index',
        value: 1165,
        desiredSize: 'smaller',
      },
      {
        name: 'Transfer Size (KB)',
        value: '1065.1',
        desiredSize: 'smaller',
      },
    ],
  },
];

// Load Performance Testing
export const headLoadPerformance = {
  metrics: {
    checks: {
      fails: 0,
      passes: 45,
      value: 0,
    },
    http_req_waiting: {
      avg: 104.3543911111111,
      max: 247.8693,
      med: 99.1985,
      min: 98.1397,
      'p(90)': 100.60016,
      'p(95)': 125.45588000000023,
    },
    http_reqs: {
      count: 45,
      rate: 8.999484329547917,
    },
  },
};

export const baseLoadPerformance = {
  metrics: {
    checks: {
      fails: 0,
      passes: 39,
      value: 0,
    },
    http_req_waiting: {
      avg: 118.28965641025643,
      max: 674.4383,
      med: 98.2503,
      min: 97.1357,
      'p(90)': 104.09862000000001,
      'p(95)': 101.22848,
    },
    http_reqs: {
      count: 39,
      rate: 7.799590989448514,
    },
  },
};

export const codequalityParsedIssues = [
  {
    name: 'Insecure Dependency',
    fingerprint: 'ca2e59451e98ae60ba2f54e3857c50e5',
    path: 'Gemfile.lock',
    line: 12,
    urlPath: 'foo/Gemfile.lock',
    severity: 'minor',
  },
];

export { mockStore };

export const mockEnforcedSecurityPolicyViolation = {
  dismissed: false,
  enforcementType: 'ENFORCE',
  name: 'Prevent Critical Vulnerabilities',
  reportType: 'SCAN_FINDING',
  securityPolicyId: '2',
  status: 'FAILED',
  __typename: 'PolicyViolationInfo',
};

export const mockWarnSecurityPolicyViolation = {
  dismissed: false,
  enforcementType: 'WARN',
  name: 'Warn mode - 01',
  reportType: 'ANY_MERGE_REQUEST',
  securityPolicyId: '8',
  status: 'FAILED',
  __typename: 'PolicyViolationInfo',
};

export const mockBypassStatus = {
  __typename: 'PolicyBypassStatus',
  allowBypass: true,
  bypassed: false,
  id: 'gid://gitlab/Security::Policy/182',
  name: 'Prevent Critical Vulnerabilities',
};

export const mockFindingReportsComparerSuccessResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/1',
        findingReportsComparer: {
          status: 'PARSED',
          report: {
            added: [
              {
                title: 'Improper neutralization of directives in dynamically evaluated code',
                uuid: '561f85b8-0ca7-5ac4-9766-15b063f16e3b',
                severity: 'HIGH',
                state: 'DETECTED',
                foundByPipelineIid: '4',
                aiResolutionEnabled: true,
                matchesAutoDismissPolicy: false,
                __typename: 'ComparedSecurityReportFinding',
              },
            ],
            fixed: [],
          },
        },
      },
    },
  },
};

export const mockFindingReportsComparerSuccessResponseWithFixed = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/1',
        findingReportsComparer: {
          status: 'PARSED',
          report: {
            added: [],
            fixed: [
              {
                title: 'Improper neutralization of directives in dynamically evaluated code',
                uuid: '561f85b8-0ca7-5ac4-9766-15b063f16e3b',
                severity: 'HIGH',
                state: 'DETECTED',
                foundByPipelineIid: '4',
                aiResolutionEnabled: true,
                matchesAutoDismissPolicy: false,
                __typename: 'ComparedSecurityReportFinding',
              },
            ],
          },
        },
      },
    },
  },
};

export const mockFindingReportsComparerParsingResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/1',
        findingReportsComparer: {
          status: 'PARSING',
          report: null,
        },
      },
    },
  },
};

export const mockFindingReportsComparerEmptyResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/1',
        findingReportsComparer: {
          status: 'PARSED',
          report: {
            added: [],
            fixed: [],
          },
        },
      },
    },
  },
};

export const createMockFindingReportsComparerResponse = (
  reportType,
  findings = { added: [], fixed: [] },
) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/1',
        __typename: 'MergeRequest',
        findingReportsComparer: {
          status: 'PARSED',
          __typename: 'FindingReportsComparer',
          report: {
            ...findings,
            __typename: 'ComparedSecurityReport',
          },
        },
      },
    },
  },
});

export const createMockFinding = (overrides = {}) => ({
  uuid: '1',
  title: 'Password leak',
  severity: 'HIGH',
  state: 'DETECTED',
  foundByPipelineIid: '123',
  aiResolutionEnabled: true,
  matchesAutoDismissPolicy: false,
  __typename: 'ComparedSecurityReportFinding',
  ...overrides,
});

export const createEnabledScansQueryResponse = ({ full = {}, partial = {} } = {}) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      pipeline: {
        id: 'gid://gitlab/Ci::Pipeline/1',
        enabledSecurityScans: {
          ready: true,
          sast: false,
          dast: false,
          dependencyScanning: false,
          containerScanning: false,
          coverageFuzzing: false,
          apiFuzzing: false,
          secretDetection: false,
          clusterImageScanning: false,
          __typename: 'EnabledSecurityScans',
          ...full,
        },
        enabledPartialSecurityScans: {
          ready: true,
          sast: false,
          dast: false,
          dependencyScanning: false,
          containerScanning: false,
          coverageFuzzing: false,
          apiFuzzing: false,
          secretDetection: false,
          clusterImageScanning: false,
          __typename: 'EnabledSecurityScans',
          ...partial,
        },
      },
    },
  },
});
