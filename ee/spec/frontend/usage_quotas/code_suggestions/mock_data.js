import { subscriptionTypes } from 'ee/admin/subscriptions/show/constants';

import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q } from 'ee/constants/duo';

export const noAssignedDuoCoreAddOnData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_CORE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noAssignedDuoProAddOnData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_PRO,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noAssignedDuoEnterpriseAddOnData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_ENTERPRISE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noAssignedDuoAmazonQAddOnData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_AMAZON_Q,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noAssignedDuoAddOnsData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/8',
        name: DUO_CORE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_PRO,
        assignedQuantity: 0,
        purchasedQuantity: 15,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/4',
        name: DUO_ENTERPRISE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/5',
        name: DUO_AMAZON_Q,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/7',
        name: DUO_ENTERPRISE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/6',
        name: DUO_PRO,
        assignedQuantity: 0,
        purchasedQuantity: 15,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/8',
        name: DUO_CORE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/6',
        name: DUO_PRO,
        assignedQuantity: 0,
        purchasedQuantity: 15,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noPurchasedAddOnData = {
  data: {
    addOnPurchases: [],
  },
};

export const purchasedAddOnFuzzyData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: DUO_PRO,
        assignedQuantity: 0,
        purchasedQuantity: null,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const currentLicenseData = {
  data: {
    currentLicense: {
      id: 'gid://gitlab/License/3',
      type: subscriptionTypes.LEGACY_LICENSE,
      activatedAt: '2021-03-01',
      billableUsersCount: '8',
      expiresAt: '2025-08-01',
      company: 'ACME Corp',
      email: 'user@acmecorp.com',
      lastSync: '2021-03-01T00:00:00.000',
      maximumUserCount: '8',
      name: 'Jane Doe',
      plan: 'ultimate',
      startsAt: '2021-03-01',
      subscriptionName: 'A-S00123456',
      usersInLicenseCount: '10',
      usersOverLicenseCount: '0',
      trial: false,
      hasGitlabCreditsAddOn: false,
      __typename: 'CurrentLicense',
    },
  },
};

export const mockSMUserWithAddOnAssignment = {
  id: 'gid://gitlab/User/1',
  username: 'userone',
  name: 'User One',
  publicEmail: null,
  avatarUrl: 'path/to/img_userone',
  webUrl: 'path/to/userone',
  lastActivityOn: '2023-08-25',
  lastDuoActivityOn: '2023-08-25',
  maxRole: null,
  addOnAssignments: {
    nodes: [{ addOnPurchase: { name: DUO_PRO } }],
    __typename: 'UserAddOnAssignmentConnection',
  },
  __typename: 'AddOnUser',
};

export const mockSMUserWithNoAddOnAssignment = {
  id: 'gid://gitlab/User/2',
  username: 'usertwo',
  name: 'User Two',
  publicEmail: null,
  avatarUrl: 'path/to/img_usertwo',
  webUrl: 'path/to/usertwo',
  lastActivityOn: '2023-08-22',
  lastDuoActivityOn: null,
  maxRole: null,
  addOnAssignments: { nodes: [], __typename: 'UserAddOnAssignmentConnection' },
  __typename: 'AddOnUser',
};

export const mockAnotherSMUserWithNoAddOnAssignment = {
  id: 'gid://gitlab/User/3',
  username: 'userthree',
  name: 'User Three',
  publicEmail: null,
  avatarUrl: 'path/to/img_userthree',
  webUrl: 'path/to/userthree',
  lastActivityOn: '2023-03-19',
  lastDuoActivityOn: '2023-01-20',
  maxRole: null,
  addOnAssignments: { nodes: [], __typename: 'UserAddOnAssignmentConnection' },
  __typename: 'AddOnUser',
};

export const mockUserWithAddOnAssignment = {
  ...mockSMUserWithAddOnAssignment,
  membershipType: null,
};

export const mockUserWithNoAddOnAssignment = {
  ...mockSMUserWithNoAddOnAssignment,
  membershipType: null,
};

export const mockAnotherUserWithNoAddOnAssignment = {
  ...mockAnotherSMUserWithNoAddOnAssignment,
  membershipType: null,
};

export const eligibleUsers = [
  mockUserWithAddOnAssignment,
  mockUserWithNoAddOnAssignment,
  mockAnotherUserWithNoAddOnAssignment,
];
export const eligibleSMUsers = [mockSMUserWithAddOnAssignment, mockSMUserWithNoAddOnAssignment];
export const eligibleUsersWithMaxRole = eligibleUsers.map((user) => ({
  ...user,
  maxRole: 'developer',
}));

const pageInfo = {
  startCursor: 'start-cursor',
  endCursor: 'end-cursor',
  __typename: 'PageInfo',
};

export const pageInfoWithNoPages = {
  hasNextPage: false,
  hasPreviousPage: false,
  ...pageInfo,
};

export const pageInfoWithMorePages = {
  hasNextPage: true,
  hasPreviousPage: true,
  ...pageInfo,
};

export const mockAddOnEligibleUsers = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers,
        pageInfo: pageInfoWithNoPages,
        __typename: 'AddOnUserConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const mockPaginatedAddOnEligibleUsers = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers,
        pageInfo: pageInfoWithMorePages,
      },
    },
  },
};

export const mockPaginatedAddOnEligibleUsersWithMembershipType = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers.map((user) => ({ ...user, membershipType: 'group_invite' })),
        pageInfo: pageInfoWithMorePages,
      },
    },
  },
};

export const mockNoGroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/95',
      name: 'Code Suggestions Group',
      fullName: 'Code Suggestions Group',
      fullPath: 'code-suggestions-group',
      __typename: 'Group',
      descendantGroups: {
        nodes: [],
        pageInfo: {},
        __typename: 'GroupConnection',
      },
    },
  },
};

export const mockGroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/95',
      name: 'Code Suggestions Group',
      fullName: 'Code Suggestions Group',
      fullPath: 'code-suggestions-group',
      __typename: 'Group',
      descendantGroups: {
        nodes: [
          {
            id: 'gid://gitlab/Group/99',
            name: 'Code Suggestions Subgroup',
            fullName: 'Code Suggestions Group / Code Suggestions Subgroup',
            fullPath: 'code-suggestions-group/code-suggestions-subgroup',
            __typename: 'Group',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          __typename: 'PageInfo',
        },
        __typename: 'GroupConnection',
      },
    },
  },
};

export const mockNoProjects = {
  data: {
    group: {
      projects: {
        nodes: [],
        __typename: 'ProjectConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockProjects = {
  data: {
    group: {
      id: 'gid://gitlab/Group/13',
      projects: {
        nodes: [
          {
            id: 'gid://gitlab/Project/20',
            name: 'A Project',
            __typename: 'Project',
          },
          {
            id: 'gid://gitlab/Project/19',
            name: 'Another Project',
            __typename: 'Project',
          },
        ],
        __typename: 'ProjectConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockHandRaiseLeadData = {
  glmContent: 'code-suggestions',
  productInteraction: 'Requested Contact-Duo Pro Add-On',
  buttonAttributes: {},
  ctaTracking: {},
};

export const MOCK_NETWORK_PROBES = {
  success: [
    {
      name: 'host_probe',
      success: true,
      message: 'customers.staging.gitlab.com reachable.',
      details: {},
      errors: [],
    },
    {
      name: 'host_probe',
      success: true,
      message: 'cloud.gitlab.com reachable.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'host_probe',
      success: false,
      message: 'customers.staging.gitlab.com is not reachable.',
      details: {},
      errors: [],
    },
    {
      name: 'host_probe',
      success: false,
      message: 'cloud.gitlab.com is not reachable.',
      details: {},
      errors: [],
    },
  ],
};

export const MOCK_SYNCHRONIZATION_PROBES = {
  success: [
    {
      name: 'access_probe',
      success: true,
      message: 'Subscription can be synchronized.',
      details: {},
      errors: [],
    },
    {
      name: 'license_probe',
      success: true,
      message: 'Subscription synchronized successfully.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'access_probe',
      success: false,
      message: 'Subscription has not yet been synchronized. Synchronize your subscription.',
      details: {},
      errors: [],
    },
    {
      name: 'license_probe',
      success: false,
      message:
        'Subscription for this instance cannot be synchronized. Contact GitLab customer support to upgrade your license.',
      details: {},
      errors: [],
    },
  ],
};

export const MOCK_SYSTEM_EXCHANGE_PROBES = {
  success: [
    {
      name: 'end_to_end_probe',
      success: true,
      message: 'Authentication with GitLab Cloud services succeeded.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'end_to_end_probe',
      success: false,
      message: 'Authentication with GitLab Cloud services failed: Access token is missing',
      details: {},
      errors: [],
    },
  ],
};

export const MOCK_AI_GATEWAY_PROBES = {
  success: [
    {
      name: 'ai_gateway_url_presence_probe',
      success: true,
      message: 'Ai::Setting.instance.ai_gateway_url is set to http://aigw.example.com.',
    },
  ],
  error: [
    {
      name: 'ai_gateway_url_presence_probe',
      success: false,
      message: 'AI::Setting.instance.ai_gateway_url is not set',
    },
  ],
};

export const MOCK_CODE_SUGGESTIONS_PROBES = {
  success: [
    {
      name: 'code_suggestions_license_probe',
      success: true,
      message: 'License includes access to Code Suggestions.',
    },
  ],
  error: [
    {
      name: 'code_suggestions_license_probe',
      success: false,
      message: 'License does not provide access to Code Suggestions.',
    },
  ],
};

export const MOCK_DUO_AGENT_PLATFORM_PROBES = {
  success: [
    {
      name: 'duo_agent_platform_probe',
      success: true,
      message: 'GitLab Duo Workflow Service at duo-workflow-svc.example.com:443 is operational.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'duo_agent_platform_probe',
      success: false,
      message:
        'GitLab Duo Workflow Service at duo-workflow-svc.example.com:443 is not operational.',
      details: {},
      errors: [],
    },
  ],
};

export const MOCK_FOUNDATIONAL_FLOWS_PROBES = {
  success: [
    {
      name: 'allow_flow_execution_probe',
      success: true,
      message: 'The allow flow execution setting is enabled.',
      details: {},
      errors: [],
    },
    {
      name: 'allow_foundational_flows_probe',
      success: true,
      message: 'The allow foundational flows setting is enabled.',
      details: {},
      errors: [],
    },
    {
      name: 'compatible_runner_probe',
      success: true,
      message: 'A compatible runner is available.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'allow_flow_execution_probe',
      success: false,
      message: 'The allow flow execution setting is disabled.',
      details: {},
      errors: [],
    },
    {
      name: 'allow_foundational_flows_probe',
      success: false,
      message: 'The allow foundational flows setting is disabled.',
      details: {},
      errors: [],
    },
    {
      name: 'compatible_runner_probe',
      success: false,
      message: 'A compatible runner is not available.',
      details: {},
      errors: [],
    },
  ],
};

export const MOCK_BILLING_PREREQUISITE_PROBES = {
  success: [
    {
      name: 'billing_customers_dot_probe',
      success: true,
      message: 'customers.gitlab.com reachable.',
      details: {},
      errors: [],
    },
    {
      name: 'billing_cloud_ai_gateway_probe',
      success: true,
      message: 'cloud.gitlab.com reachable.',
      details: {},
      errors: [],
    },
    {
      name: 'billing_duo_workflow_service_probe',
      success: true,
      message:
        'The cloud GitLab Duo Agent Platform service at duo-workflow-svc.runway.gitlab.net is reachable for usage billing.',
      details: {},
      errors: [],
    },
  ],
  error: [
    {
      name: 'billing_customers_dot_probe',
      success: false,
      message: 'customers.gitlab.com connection failed: URL blocked.',
      details: {},
      errors: [],
    },
    {
      name: 'billing_cloud_ai_gateway_probe',
      success: false,
      message: 'cloud.gitlab.com connection failed: URL blocked.',
      details: {},
      errors: [],
    },
    {
      name: 'billing_duo_workflow_service_probe',
      success: false,
      message:
        'The cloud GitLab Duo Agent Platform service at duo-workflow-svc.runway.gitlab.net is not reachable.',
      details: {},
      errors: [],
    },
  ],
};
