import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_EDIT_FRAMEWORK,
} from 'ee/compliance_dashboard/constants';

export const createUser = (id) => ({
  id: `gid://gitlab/User/${id}`,
  avatarUrl: `https://${id}`,
  name: `User ${id}`,
  username: `user-${id}`,
  webUrl: `http://localhost:3000/user-${id}`,
  __typename: 'UserCore',
});

export const createApprovers = (count) => {
  return Array(count)
    .fill(null)
    .map((_, id) => ({ ...createUser(id), id }));
};

export const createDefaultProjects = (count) => {
  return Array(count)
    .fill(null)
    .map((_, id) => ({
      id,
      name: `project-${id}`,
      fullPath: `group/project-${id}`,
    }));
};

export const createDefaultProjectsResponse = (projects) => ({
  data: {
    group: {
      id: '1',
      projects: {
        nodes: projects,
        __typename: 'Project',
      },
      __typename: 'Group',
    },
  },
});

const complianceFrameworksNodesMock = [
  {
    id: 'gid://gitlab/ComplianceManagement::Framework/1',
    name: 'Example Framework',
    description: 'asds',
    color: '#0000ff',
    __typename: 'ComplianceFramework',
    default: true,
  },
];

export const createComplianceAdherence = (id, checkName, complianceFrameworksNodes) => ({
  id: `gid://gitlab/Projects::ComplianceStandards::Adherence/${id}`,
  updatedAt: 'July 1, 2023',
  status: id % 2 === 0 ? 'SUCCESS' : 'FAIL',
  checkName,
  standard: 'GITLAB',
  project: {
    id: 'gid://gitlab/Project/1',
    name: 'Example Project',
    webUrl: 'example.com/groups/example-group/example-project',
    complianceFrameworks: {
      nodes: complianceFrameworksNodes,
    },
  },
});

export const createComplianceAdherencesResponse = ({
  count = 1,
  checkName = 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR',
  pageInfo = {},
  complianceFrameworksNodes = complianceFrameworksNodesMock,
} = {}) => ({
  data: {
    container: {
      id: 'gid://gitlab/Group/1',
      __typename: 'Group',
      projectComplianceStandardsAdherence: {
        __typename: 'ComplianceStandardsAdherenceConnection',
        nodes: Array(count)
          .fill(null)
          .map((_, id) => createComplianceAdherence(id, checkName, complianceFrameworksNodes)),
        pageInfo: {
          endCursor: 'abc',
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'abc',
          __typename: 'PageInfo',
          ...pageInfo,
        },
      },
    },
  },
});

export const createComplianceViolation = (id) => ({
  id: `gid://gitlab/MergeRequests::ComplianceViolation/${id}`,
  severityLevel: 'HIGH',
  reason: 'APPROVED_BY_COMMITTER',
  violatingUser: createUser(1),
  mergeRequest: {
    id: `gid://gitlab/MergeRequest/1`,
    title: `Merge request 1`,
    mergedAt: '2022-03-06T16:39:12Z',
    webUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/merge_requests/56',
    author: createUser(2),
    mergeUser: createUser(1),
    committers: {
      nodes: [createUser(1)],
      __typename: 'UserCoreConnection',
    },
    participants: {
      nodes: [createUser(1), createUser(2)],
      __typename: 'UserCoreConnection',
    },
    approvedBy: {
      nodes: [createUser(1)],
      __typename: 'UserCoreConnection',
    },
    ref: '!56',
    fullRef: 'gitlab-org/gitlab-shell!56',
    sourceBranch: 'master',
    sourceBranchExists: false,
    targetBranch: 'feature',
    targetBranchExists: false,
    project: {
      id: 'gid://gitlab/Project/2',
      avatarUrl: null,
      name: 'Gitlab Shell',
      webUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell',
      complianceFrameworks: {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Framework/1',
            name: 'GDPR',
            description: 'asds',
            color: '#0000ff',
            __typename: 'ComplianceFramework',
          },
        ],
        __typename: 'ComplianceFrameworkConnection',
      },
      __typename: 'Project',
    },
    __typename: 'MergeRequest',
  },
  __typename: 'ComplianceViolation',
});

export const createComplianceViolationsResponse = ({ count = 1, pageInfo = {} } = {}) => ({
  data: {
    container: {
      id: 'gid://gitlab/Group/1',
      __typename: 'Group',
      mergeRequestViolations: {
        __typename: 'ComplianceViolationConnection',
        nodes: Array(count)
          .fill(null)
          .map((_, id) => createComplianceViolation(id)),
        pageInfo: {
          endCursor: 'abc',
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'abc',
          __typename: 'PageInfo',
          ...pageInfo,
        },
      },
    },
  },
});

export const complianceFramework = {
  id: 'gid://gitlab/ComplianceManagement::Framework/1',
  color: '#009966',
  description: 'General Data Protection Regulation',
  name: 'GDPR',
  pipelineConfigurationFullPath: null,
  projects: {
    nodes: [],
    __typename: 'ProjectConnection',
  },
  __typename: 'ComplianceFramework',
};

export const createComplianceFrameworkMutationResponse = (
  mutationType = 'createComplianceFramework',
  frameworkNamespace = 'framework',
) => ({
  data: {
    [mutationType]: {
      [frameworkNamespace]: complianceFramework,
      errors: [],
      clientMutationId: null,
      __typename: 'CreateComplianceFrameworkPayload',
    },
  },
});

export const createProject = ({ id, groupPath, archived = false } = {}) => ({
  id: `gid://gitlab/Project/${id}`,
  name: `Project ${id}`,
  description: `Project description ${id}`,
  webUrl: `${groupPath}/project${id}`,
  webPath: `${groupPath}/project${id}`,
  visibility: 'public',
  fullPath: `${groupPath}/project${id}`,
  archived,
  namespace: {
    webUrl: `${groupPath}`,
    webPath: `${groupPath}`,
    fullName: `Project ${id} group`,
    id: `gid://gitlab/Group/${id}`,
    name: `Group ${id}`,
  },
  complianceFrameworks: {
    nodes: [
      {
        id: `gid://gitlab/ComplianceManagement::Framework/${id}`,
        name: 'some framework',
        default: false,
        description: 'this is a framework',
        color: '#3cb371',
        namespaceId: 'gid://gitlab/Group/1',
        __typename: 'ComplianceFramework',
      },
    ],
    __typename: 'ComplianceFrameworkConnection',
  },
  __typename: 'Project',
});

export const createComplianceFrameworksResponse = ({
  count = 1,
  pageInfo = {},
  groupPath = 'foo',
  archivedProject = null,
} = {}) => {
  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        projects: {
          nodes: Array(count)
            .fill(null)
            .map((_, id) => createProject({ id, groupPath, archived: id === archivedProject })),
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'eyJpZCI6IjQxIn0',
            endCursor: 'eyJpZCI6IjIyIn0',
            __typename: 'PageInfo',
            ...pageInfo,
          },
          __typename: 'ProjectConnection',
        },
        __typename: 'Group',
      },
    },
  };
};

export const createProjectUpdateComplianceFrameworksResponse = ({ errors } = {}) => ({
  data: {
    projectUpdateComplianceFrameworks: {
      __typename: 'ProjectUpdateComplianceFrameworksPayload',
      clientMutationId: '1',
      errors: errors ?? [],
      project: createProject({ id: 1 }),
    },
  },
});

export const mockPageInfo = () => ({
  hasNextPage: true,
  hasPreviousPage: true,
  startCursor: 'start-cursor',
  endCursor: 'end-cursor',
  __typename: 'PageInfo',
});

export const createFramework = ({
  id,
  isDefault = false,
  projects = 0,
  projectsTotalCount = 100,
  groupPath = 'foo',
  options,
} = {}) => ({
  id: `gid://gitlab/ComplianceManagement::Framework/${id}`,
  name: `Auditor's framework ${id}`,
  default: isDefault,
  description: `This is a framework ${id}`,
  color: `#3cb37${id}`,
  updatedAt: '2025-04-03T02:01:00Z',
  namespaceId: id ? `gid://gitlab/Types::Namespace/${id}` : null,
  complianceRequirements: {
    nodes: [],
  },
  projects: {
    pageInfo: mockPageInfo(),
    count: projectsTotalCount,
    nodes: Array(projects)
      .fill(null)
      .map((_, pid) => createProject({ id: pid, groupPath })),
  },
  securityPolicies: {
    nodes: [
      {
        id: `gid://gitlab/Security::ScanExecutionPolicy/${id}-1`,
        name: 'scan exec 1',
        type: 'scan_execution_policy',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            fullPath: 'bar',
          },
        },
      },
      {
        id: `gid://gitlab/Security::ScanResultPolicy/${id}-1`,
        name: 'scan1',
        type: 'approval_policy',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            fullPath: 'foo',
          },
        },
      },
      {
        id: `gid://gitlab/Security::ScanResultPolicy/${id}-2`,
        name: 'scan2',
        type: 'approval_policy',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            fullPath: 'bar',
          },
        },
      },
      {
        id: `gid://gitlab/Security::PipelineExecutionPolicy/${id}-1`,
        name: 'pipeline exec 1',
        type: 'pipeline_execution_policy',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            fullPath: 'bar',
          },
        },
      },
      {
        id: `gid://gitlab/Security::VulnerabilityManagementPolicy/${id}-1`,
        name: 'vuln management 1',
        type: 'vulnerability_management_policy',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            fullPath: 'bar',
          },
        },
      },
    ],
    pageInfo: {
      hasNextPage: false,
      endCursor: null,
    },
  },
  pipelineConfigurationFullPath: null,
  __typename: 'ComplianceFramework',
  ...options,
});

export const createComplianceFrameworksTokenResponse = () => {
  return {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Shell',
        __typename: 'Namespace',
        complianceFrameworks: {
          pageInfo: mockPageInfo(),
          nodes: [
            createFramework({
              id: 1,
            }),
            createFramework({
              id: 2,
            }),
          ],
          __typename: 'ComplianceFrameworkConnection',
        },
      },
    },
  };
};

const securityPolicyBlob = `---
pipeline_execution_policy:
- name: test
  description: ''
  enabled: true
  pipeline_config_strategy: override_project_ci
  content:
    include:
    - project: Commit451/commit451-security-policy-project
      file: ".gitlab/security-policies/policy.yml"
  policy_scope:
    compliance_frameworks:
    - id: 1
  metadata:
    compliance_pipeline_migration: true
`;

export const createComplianceFrameworksReportResponse = ({
  count = 1,
  projects = 0,
  projectsTotalCount = 100,
  groupPath = 'group',
} = {}) => {
  return {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Org',
        securityPolicyProject: {
          id: 'gid://gitlab/Project/20',
          repository: {
            blobs: {
              nodes: [
                {
                  id: 'gid://gitlab/Blob/1',
                  rawBlob: securityPolicyBlob,
                },
              ],
            },
          },
        },
        complianceFrameworks: {
          pageInfo: mockPageInfo(),
          nodes: Array(count)
            .fill(null)
            .map((_, id) =>
              createFramework({ id: id + 1, projects, projectsTotalCount, groupPath }),
            ),
          __typename: 'ComplianceFrameworkConnection',
        },
        __typename: 'Namespace',
      },
    },
  };
};

export const createComplianceFrameworksReportProjectsResponse = ({ count = 1 } = {}) => {
  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Org',
        projects: {
          nodes: Array(count)
            .fill(null)
            .map((_, id) => createProject({ id })),
          __typename: 'ProjectConnection',
        },
        __typename: 'Group',
      },
    },
  };
};

export const createDeleteFrameworkResponse = (errors = []) => ({
  data: {
    destroyComplianceFramework: {
      errors,
      __typename: 'DestroyComplianceFrameworkPayload',
    },
  },
});

export const mockRequirements = [
  {
    id: 'gid://gitlab/ComplianceManagement::Requirement/1',
    name: 'SOC2',
    description: 'Controls for SOC2',
    __typename: 'ComplianceManagement::Requirement',
    complianceRequirementsControls: {
      nodes: [],
    },
  },
  {
    id: 'gid://gitlab/ComplianceManagement::Requirement/2',
    name: 'GitLab',
    description: 'Controls used by GitLab',
    __typename: 'ComplianceManagement::Requirement',
    complianceRequirementsControls: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Control/1',
          name: 'minimum_approvals_required',
          controlType: 'internal',
          externalControlName: null,
          externalUrl: null,
          pingEnabled: null,
          expression: {
            field: 'minimum_approvals_required',
            operator: '=',
            value: 1,
            __typename: 'IntegerExpression',
          },
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Control/2',
          name: 'scanner_sast_running',
          controlType: 'internal',
          externalControlName: null,
          externalUrl: null,
          pingEnabled: null,
          expression: {
            field: 'scanner_sast_running',
            operator: '=',
            value: true,
            __typename: 'BooleanExpression',
          },
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/ComplianceManagement::Requirement/3',
    name: 'External',
    description: 'Requirement with external control',
    __typename: 'ComplianceManagement::Requirement',
    complianceRequirementsControls: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Control/3',
          name: 'external_control',
          controlType: 'external',
          externalControlName: 'external_name',
          externalUrl: 'https://example.com',
          pingEnabled: true,
          expression: null,
        },
      ],
    },
  },
];

export const mockGitLabStandardControls = [
  {
    id: 'scanner_sast_running',
    name: 'SAST Running',
    expression: {
      field: 'scanner_sast_running',
      operator: '=',
      value: true,
      __typename: 'BooleanExpression',
    },
    __typename: 'ControlExpression',
  },
  {
    id: 'minimum_approvals_required',
    name: 'Minimum approvals required',
    expression: {
      field: 'minimum_approvals_required',
      operator: '=',
      value: 1,
      __typename: 'IntegerExpression',
    },
    __typename: 'ControlExpression',
  },
  {
    id: 'minimum_approvals_required_1',
    name: 'At least one approval',
    expression: {
      field: 'minimum_approvals_required',
      operator: '=',
      value: 1,
      __typename: 'IntegerExpression',
    },
    __typename: 'ControlExpression',
  },
  {
    id: 'minimum_approvals_required_2',
    name: 'At least two approvals',
    expression: {
      field: 'minimum_approvals_required',
      operator: '=',
      value: 2,
      __typename: 'IntegerExpression',
    },
    __typename: 'ControlExpression',
  },
  {
    id: 'default_branch_protected',
    name: 'Default branch protected',
    expression: {
      field: 'default_branch_protected',
      operator: '=',
      value: true,
      __typename: 'BooleanExpression',
    },
    __typename: 'ControlExpression',
  },
];

export const mockInternalControls = [
  {
    name: 'minimum_approvals_required',
    controlType: 'internal',
    displayValue: 'Minimum approvals required',
  },
  {
    name: 'scanner_sast_running',
    controlType: 'internal',
    displayValue: 'SAST Running',
  },
];

export const mockExternalControl = {
  name: 'external_control',
  controlType: 'external',
  displayValue: 'external_name',
};

export const mockExternalControlWithPingDisabled = {
  name: 'external_control_ping_disabled',
  controlType: 'external',
  displayValue: 'external_name_ping_disabled',
  pingEnabled: false,
};

export const mockedRoutes = [
  { name: ROUTE_STANDARDS_ADHERENCE, fullPath: `/${ROUTE_STANDARDS_ADHERENCE}` },
  { name: ROUTE_VIOLATIONS, fullPath: `/${ROUTE_VIOLATIONS}` },
  { name: ROUTE_FRAMEWORKS, fullPath: `/${ROUTE_FRAMEWORKS}` },
  { name: ROUTE_PROJECTS, fullPath: `/${ROUTE_PROJECTS}` },
  { name: ROUTE_NEW_FRAMEWORK, fullPath: `/${ROUTE_FRAMEWORKS}/new` },
  { name: ROUTE_NEW_FRAMEWORK_SUCCESS, fullPath: `/${ROUTE_FRAMEWORKS}/new/success` },
  { name: ROUTE_EDIT_FRAMEWORK, fullPath: `/${ROUTE_FRAMEWORKS}/123` },
];

export const createFrameworkResponseWithEmptyPolicies = () => {
  const response = createComplianceFrameworksReportResponse();
  const framework = response.data.namespace.complianceFrameworks.nodes[0];

  framework.securityPolicies = { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } };

  return response;
};

export const createFrameworkResponseWithPolicy = (policyType) => {
  const response = createFrameworkResponseWithEmptyPolicies();
  const framework = response.data.namespace.complianceFrameworks.nodes[0];

  framework.securityPolicies = {
    nodes: [
      {
        id: `gid://gitlab/Security::Policy/1`,
        name: policyType.replace(/_/g, ' '),
        type: policyType,
      },
    ],
    pageInfo: { hasNextPage: false, endCursor: null },
  };

  return response;
};

export const addRequirementsToFrameworks = (frameworksData) => {
  return frameworksData.map((framework) => ({
    ...framework,
    complianceRequirements: {
      nodes: mockRequirements,
    },
  }));
};

export const createManyRequirements = (count = 15) => {
  return Array(count)
    .fill()
    .map((_, i) => ({
      id: `gid://gitlab/ComplianceManagement::Requirement/${i + 10}`,
      name: `Requirement ${i}`,
      description: `Description ${i}`,
      __typename: 'ComplianceManagement::Requirement',
      complianceRequirementsControls: { nodes: [] },
    }));
};

export const createFrameworksWithManyRequirements = (frameworksData, count = 15) => {
  const manyRequirements = createManyRequirements(count);
  return frameworksData.map((framework) => ({
    ...framework,
    complianceRequirements: { nodes: manyRequirements },
  }));
};
