export const mockDefaultPermissions = [
  {
    value: 'A',
    name: 'A',
    description: 'A',
    requirements: null,
    enabledForGroupAccessLevels: null,
    enabledForProjectAccessLevels: null,
  },
  {
    value: 'B',
    name: 'B',
    description: 'B',
    requirements: ['A'],
    enabledForGroupAccessLevels: null,
    enabledForProjectAccessLevels: null,
  },
  {
    value: 'C',
    name: 'C',
    description: 'C',
    requirements: ['B'],
    enabledForGroupAccessLevels: null,
    enabledForProjectAccessLevels: null,
  }, // Nested dependency: C -> B -> A
  {
    value: 'D',
    name: 'D',
    description: 'D',
    requirements: ['C'],
    enabledForGroupAccessLevels: ['DEVELOPER'],
    enabledForProjectAccessLevels: ['MAINTAINER'],
  }, // Nested dependency: D -> C -> B -> A
  {
    value: 'E',
    name: 'E',
    description: 'E',
    requirements: ['F'],
    enabledForGroupAccessLevels: ['DEVELOPER'],
    enabledForProjectAccessLevels: ['DEVELOPER', 'MAINTAINER'],
  }, // Circular dependency
  {
    value: 'F',
    name: 'F',
    description: 'F',
    requirements: ['E'],
    enabledForGroupAccessLevels: ['DEVELOPER'],
    enabledForProjectAccessLevels: null,
  }, // Circular dependency
  {
    value: 'G',
    name: 'G',
    description: 'G',
    requirements: ['A', 'B', 'C'],
    enabledForGroupAccessLevels: null,
    enabledForProjectAccessLevels: ['DEVELOPER'],
  }, // Multiple dependencies
  {
    value: 'READ_CODE',
    name: 'Read code',
    description: 'Read code',
    requirements: null,
    enabledForGroupAccessLevels: null,
    enabledForProjectAccessLevels: ['DEVELOPER'],
  },
];

export const mockPermissionsResponse = {
  data: {
    memberRolePermissions: {
      nodes: mockDefaultPermissions,
    },
  },
};

export const standardRoles = [
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/GUEST',
    accessLevel: 10,
    name: 'Guest',
    detailsPath: 'role/GUEST',
    description:
      'The Guest role is for users who need visibility into a project or group but should not have the ability to make changes, such as external stakeholders.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/PLANNER',
    accessLevel: 15,
    name: 'Planner',
    detailsPath: 'role/PLANNER',
    description:
      'The Guest role is for users who need visibility into a project or group but should not have the ability to make changes, such as external stakeholders..',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/REPORTER',
    accessLevel: 20,
    name: 'Reporter',
    detailsPath: 'role/REPORTER',
    description:
      'The Reporter role is suitable for team members who need to stay informed about a project or group but do not actively contribute code.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/SECURITY_MANAGER',
    accessLevel: 25,
    name: 'Security Manager',
    detailsPath: 'role/SECURITY_MANAGER',
    description:
      'The Security Manager role provides comprehensive access to security features, including vulnerability management, security dashboards, policy configuration, and compliance tools.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/DEVELOPER',
    accessLevel: 30,
    name: 'Developer',
    detailsPath: 'role/DEVELOPER',
    description:
      'The Developer role gives users access to contribute code while restricting sensitive administrative actions.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/MAINTAINER',
    accessLevel: 40,
    name: 'Maintainer',
    detailsPath: 'role/MAINTAINER',
    description:
      'The Maintainer role is primarily used for managing code reviews, approvals, and administrative settings for projects. This role can also manage project memberships.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/OWNER',
    accessLevel: 50,
    name: 'Owner',
    detailsPath: 'role/OWNER',
    description:
      'The Owner role is typically assigned to the individual or team responsible for managing and maintaining the group or creating the project. This role has the highest level of administrative control, and can manage all aspects of the group or project, including managing other Owners.',
  },
];

export const memberRoles = [
  {
    id: 'gid://gitlab/MemberRole/1',
    name: 'Custom role 1',
    description: 'Custom role 1 description',
    usersCount: 0,
    editPath: 'edit/path/1',
    dependentSecurityPolicies: [],
    detailsPath: 'details/path/1',
    __typename: 'MemberRole',
  },
  {
    id: 'gid://gitlab/MemberRole/2',
    name: 'Custom role 2',
    description: 'Custom role 2 description',
    usersCount: 1,
    editPath: 'edit/path/2',
    dependentSecurityPolicies: [],
    detailsPath: 'details/path/2',
    __typename: 'MemberRole',
  },
];

export const adminRoles = [
  {
    id: 'gid://gitlab/MemberRole/3',
    name: 'Admin role 1',
    description: 'Admin role 1 description',
    usersCount: 0,
    editPath: 'role/path/3/edit',
    detailsPath: 'role/path/3',
    ldapAdminRoleLinks: { nodes: [] },
    __typename: 'AdminMemberRole',
  },
  {
    id: 'gid://gitlab/MemberRole/4',
    name: 'Admin role 2',
    description: 'Admin role 2 description',
    usersCount: 0,
    editPath: 'role/path/4/edit',
    detailsPath: 'role/path/4',
    ldapAdminRoleLinks: { nodes: [] },
    __typename: 'AdminMemberRole',
  },
];

export const groupRolesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      standardRoles: { nodes: standardRoles },
      memberRoles: { nodes: memberRoles },
    },
  },
};

export const instanceRolesResponse = {
  data: {
    standardRoles: { nodes: standardRoles },
    memberRoles: { nodes: memberRoles },
    adminMemberRoles: { nodes: adminRoles },
  },
};

export const saasAdminRolesResponse = {
  data: {
    adminMemberRoles: { nodes: adminRoles },
  },
};

export const ldapAdminRoleLinks = [
  {
    id: 'gid://gitlab/Authz::LdapAdminRoleLink/1',
    provider: {
      id: 'ldapmain',
      label: 'LDAP',
    },
    cn: null,
    filter: 'cn=group1,ou=groups,dc=example,dc=com',
    adminMemberRole: { id: 'gid://gitlab/MemberRole/1', name: 'Custom admin role 1' },
    createdAt: '2020-07-04T21:14:54Z',
    syncStatus: 'NEVER_SYNCED',
    syncStartedAt: null,
    syncEndedAt: null,
    syncError: null,
    lastSuccessfulSyncAt: null,
  },
  {
    id: 'gid://gitlab/Authz::LdapAdminRoleLink/2',
    provider: {
      id: 'ldapalt',
      label: 'LDAP alt',
    },
    cn: 'group2',
    filter: null,
    adminMemberRole: { id: 'gid://gitlab/MemberRole/2', name: 'Custom admin role 2' },
    createdAt: '2020-07-04T21:14:54Z',
    syncStatus: 'SUCCESSFUL',
    syncStartedAt: '2020-07-05T23:55:24Z',
    syncEndedAt: '2020-07-05T23:57:31Z',
    syncError: null,
    lastSuccessfulSyncAt: '2020-07-04T21:14:54Z',
  },
];

export const mockMemberRole = {
  id: 1,
  name: 'Custom role',
  description: 'Custom role description',
  createdAt: '2024-08-04T12:20:43Z',
  editPath: 'role/path/1/edit',
  detailsPath: 'role/path/1',
  usersCount: 0,
  baseAccessLevel: { stringValue: 'DEVELOPER', humanAccess: 'Developer' },
  enabledPermissions: { nodes: [{ value: 'A' }, { value: 'B' }] },
  dependentSecurityPolicies: [],
  __typename: 'MemberRole',
};
export const mockMemberRoleWithUsers = { ...mockMemberRole, usersCount: 2 };
export const mockMemberRoleWithSecurityPolicies = {
  ...mockMemberRole,
  dependentSecurityPolicies: [
    { id: 'gid://gitlab/Security::OrchestrationPolicy/1', name: 'policy 1', editPath: 'path/1' },
    { id: 'gid://gitlab/Security::OrchestrationPolicy/2', name: 'policy 2', editPath: 'path/2' },
  ],
};

export const mockAdminRole = {
  id: 2,
  name: 'Admin role',
  description: 'Admin role description',
  createdAt: '2024-08-04T12:20:43Z',
  editPath: 'role/path/2/edit',
  detailsPath: 'role/path/2',
  usersCount: 0,
  enabledPermissions: { nodes: [{ value: 'C' }, { value: 'D' }] },
  __typename: 'AdminMemberRole',
};
export const mockAdminRoleWithUsers = { ...mockAdminRole, usersCount: 2 };
export const mockAdminRoleWithLdapLinks = {
  ...mockAdminRole,
  ldapAdminRoleLinks: { nodes: ldapAdminRoleLinks },
};

export const getMemberRoleQueryResponse = (memberRole = mockMemberRole) => ({
  data: { memberRole },
});

export const ldapServers = [
  { value: 'ldapmain', text: 'LDAP' },
  { value: 'ldapalt', text: 'LDAP-alt' },
];

export const ROLE_LINK_NEVER_SYNCED = {
  ...ldapAdminRoleLinks[0],
  syncStatus: 'NEVER_SYNCED',
};
export const ROLE_LINK_QUEUED = {
  ...ROLE_LINK_NEVER_SYNCED,
  syncStatus: 'QUEUED',
  lastSuccessfulSyncAt: '2020-07-04T12:55:19Z',
};
export const ROLE_LINK_RUNNING = {
  ...ROLE_LINK_QUEUED,
  syncStatus: 'RUNNING',
  syncStartedAt: '2020-07-05T23:55:24Z',
};
export const ROLE_LINK_SUCCESSFUL = {
  ...ROLE_LINK_RUNNING,
  syncStatus: 'SUCCESSFUL',
  syncEndedAt: '2020-07-05T23:57:31Z',
};
export const ROLE_LINK_FAILED = {
  ...ROLE_LINK_SUCCESSFUL,
  syncStatus: 'FAILED',
  syncError: 'oh no',
};

export const newCustomRoleOption = {
  text: 'Member role',
  href: 'new/role/path',
  description: 'Create a role to manage member permissions for groups and projects.',
};

export const newAdminRoleOption = {
  text: 'Admin role',
  href: 'new/role/path?admin',
  description: 'Create a role to manage permissions in the Admin area.',
};

export const permissionWithoutChildren = {
  name: 'Permission A',
  value: 'PERMISSION_A',
  checked: false,
  disabled: false,
};
export const permissionWithChildren = {
  name: 'Permission B',
  value: 'PERMISSION_B',
  checked: true,
  disabled: true,
  children: [{ value: 'PERMISSION_C' }, { value: 'PERMISSION_D' }],
};
