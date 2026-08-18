import { groupBy } from 'lodash-es';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';

export const defaultPageInfo = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
};

const mockPolicyResponse = ({ nodes = [], namespaceType, policyType }) =>
  jest.fn().mockResolvedValue({
    data: {
      namespace: {
        id: '3',
        __typename: namespaceType,
        [policyType]: {
          nodes,
        },
      },
    },
  });

const mockPoliciesResponse = ({ nodes = [], pageInfo = defaultPageInfo }) =>
  jest.fn().mockResolvedValue({
    data: {
      namespace: {
        id: '1',
        securityPolicies: {
          nodes: nodes.map((node) => ({
            ...node,
            testRuns: node.testRuns || { nodes: [] },
          })),
          pageInfo,
        },
      },
    },
  });

export const projectScanExecutionPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Project', policyType: 'scanExecutionPolicies' });
export const groupScanExecutionPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Group', policyType: 'scanExecutionPolicies' });

export const projectScanResultPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Project', policyType: 'scanResultPolicies' });
export const groupScanResultPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Group', policyType: 'scanResultPolicies' });

export const projectPipelineResultPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Project', policyType: 'pipelineExecutionPolicies' });
export const groupPipelineResultPolicies = (nodes) =>
  mockPolicyResponse({ nodes, namespaceType: 'Group', policyType: 'pipelineExecutionPolicies' });

export const projectSecurityPolicies = (nodes, pageInfo = defaultPageInfo) =>
  mockPoliciesResponse({ nodes, pageInfo });
export const groupSecurityPolicies = (nodes, pageInfo = defaultPageInfo) =>
  mockPoliciesResponse({ nodes, pageInfo });

export const projectPipelineExecutionSchedulePolicies = (nodes) =>
  mockPolicyResponse({
    nodes,
    namespaceType: 'Project',
    policyType: 'pipelineExecutionSchedulePolicies',
  });
export const groupPipelineExecutionSchedulePolicies = (nodes) =>
  mockPolicyResponse({
    nodes,
    namespaceType: 'Group',
    policyType: 'pipelineExecutionSchedulePolicies',
  });

export const projectVulnerabilityManagementPolicies = (nodes) =>
  mockPolicyResponse({
    nodes,
    namespaceType: 'Project',
    policyType: 'vulnerabilityManagementPolicies',
  });
export const groupVulnerabilityManagementPolicies = (nodes) =>
  mockPolicyResponse({
    nodes,
    namespaceType: 'Group',
    policyType: 'vulnerabilityManagementPolicies',
  });

export const mockLinkSecurityPolicyProjectResponses = {
  success: jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectAssign: {
        errors: [],
        __typename: 'SecurityPolicyProjectAssignPayload',
      },
    },
  }),
  failure: jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectAssign: {
        errors: ['link failed'],
        __typename: 'SecurityPolicyProjectAssignPayload',
      },
    },
  }),
};

export const mockUnlinkSecurityPolicyProjectResponses = {
  success: jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectUnassign: {
        errors: [],
        __typename: 'SecurityPolicyProjectUnassignPayload',
      },
    },
  }),
  failure: jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectUnassign: {
        errors: ['unlink failed'],
        __typename: 'SecurityPolicyProjectUnassignPayload',
      },
    },
  }),
};

export const complianceFrameworksResponse = [
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 1),
    name: 'A1',
    default: true,
    description: 'description 1',
    editPath: '/edit/framework/1',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 1',
    projects: { nodes: [] },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 2),
    name: 'B2',
    default: false,
    description: 'description 2',
    editPath: '/edit/framework/2',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 2',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
        },
      ],
    },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 3),
    name: 'a3',
    default: true,
    description: 'description 3',
    editPath: '/edit/framework/3',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 3',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
        },
        {
          id: '2',
          name: 'project-2',
        },
      ],
    },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 4),
    name: 'a4',
    default: true,
    description: 'description 4',
    editPath: '',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 4',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
        },
        {
          id: '2',
          name: 'project-2',
        },
      ],
      pageInfo: {
        hasNextPage: true,
      },
    },
  },
];

export const groupByType = (list) => {
  const flattenedList = list.map(({ policyAttributes = {}, ...policy }) => ({
    ...policy,
    ...policyAttributes,
    testRuns: policy.testRuns || { nodes: [] },
  }));
  return groupBy(flattenedList, 'type');
};

export const mockLinkedSppItemsResponse = ({
  projects = [],
  namespaces = [],
  groups = [],
  pageInfo = defaultPageInfo,
} = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      project: {
        __typename: 'Project',
        id: '1',
        securityPolicyProjectLinkedProjects: {
          nodes: projects,
          pageInfo,
        },
        securityPolicyProjectLinkedNamespaces: {
          nodes: namespaces,
          pageInfo,
        },
        securityPolicyProjectLinkedGroups: {
          nodes: groups,
          pageInfo,
        },
      },
    },
  });

export const MOCK_POLICY_CONFIGURATION_ID =
  'gid://gitlab/Security::OrchestrationPolicyConfiguration/1';

export const POLICY_SCOPE_MOCK = {
  policyScope: {
    __typename: 'PolicyScope',
    complianceFrameworks: {
      nodes: [],
    },
    excludingPersonalProjects: false,
    excludingProjects: {
      nodes: [],
    },
    includingProjects: {
      nodes: [],
    },
    includingGroups: {
      nodes: [],
    },
    includingBusinessImpactAttributes: { count: 0, nodes: [] },
    excludingBusinessImpactAttributes: { count: 0, nodes: [] },
    includingApplicationAttributes: { count: 0, nodes: [] },
    excludingApplicationAttributes: { count: 0, nodes: [] },
    includingBusinessUnitAttributes: { count: 0, nodes: [] },
    excludingBusinessUnitAttributes: { count: 0, nodes: [] },
    includingExposureAttributes: { count: 0, nodes: [] },
    excludingExposureAttributes: { count: 0, nodes: [] },
  },
};
