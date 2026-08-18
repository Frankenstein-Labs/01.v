const TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD = 'ProjectSecretsPermissionUpdatePayload';
const TYPENAME_SECRET_PERMISSION = 'ProjectSecretsPermission';

export const entitlementResponse = ({
  onDemandEnabled = true,
  state = 'PAID',
  blockedReason = null,
} = {}) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      secretsManagerEntitlement: {
        state,
        blockedReason,
        trialStartedAt: null,
        trialExpiresAt: null,
        creditsRemaining: 50,
        creditsTotal: 500,
        onDemandEnabled,
        __typename: 'SecretsManagerEntitlement',
      },
      __typename: 'Group',
    },
  },
});

export const openbaoHealthResponse = (healthy = true) => ({
  data: { openbaoHealth: healthy },
});

export const enrollmentStatusResponse = ({ enrolled = true } = {}) => ({
  data: {
    namespaceSecretsManagerEnrollment: !enrolled
      ? null
      : {
          namespace: {
            id: 'gid://gitlab/Group/101',
            __typename: 'Namespace',
          },
          __typename: 'SecretsManagerEnrollment',
        },
  },
});

export const enrollNamespaceResponse = ({ errors = [] } = {}) => ({
  data: {
    namespaceSecretsManagerEnroll: {
      enrollment: {
        namespace: {
          id: 'gid://gitlab/Group/101',
          __typename: 'Namespace',
        },
        __typename: 'SecretsManagerEnrollment',
      },
      errors,
      __typename: 'NamespaceSecretsManagerEnrollPayload',
    },
  },
});

export const unenrollNamespaceResponse = ({ errors = [] } = {}) => ({
  data: {
    namespaceSecretsManagerUnenroll: {
      enrollment: null,
      errors,
      __typename: 'NamespaceSecretsManagerUnenrollPayload',
    },
  },
});

export const secretManagerSettingsResponse = (status, errors = undefined) => {
  return {
    data: {
      secretsManager: {
        entity: {
          id: 'gid://gitlab/Project/96',
          archived: false,
          markedForDeletion: false,
        },
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
    errors,
  };
};

export const initializeSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      projectSecretsManagerInitialize: {
        errors,
        projectSecretsManager: {
          status: 'PROVISIONING',
        },
        __typename: 'ProjectSecretsManagerInitializePayload',
      },
    },
  };
};

export const groupSecretManagerSettingsResponse = (status, errors = undefined) => {
  return {
    data: {
      secretsManager: {
        entity: {
          id: 'gid://gitlab/Group/96',
          archived: false,
          markedForDeletion: false,
        },
        status,
        __typename: 'GroupSecretsManager',
      },
    },
    errors,
  };
};

export const initializeGroupSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      groupSecretsManagerInitialize: {
        errors,
        groupSecretsManager: {
          status: 'PROVISIONING',
        },
        __typename: 'GroupSecretsManagerInitializePayload',
      },
    },
  };
};

export const deprovisionSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      projectSecretsManagerDeprovision: {
        errors,
        projectSecretsManager: {
          status: 'DEPROVISIONING',
        },
        __typename: 'ProjectSecretsManagerDeprovisionPayload',
      },
    },
  };
};

export const deprovisionGroupSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      groupSecretsManagerDeprovision: {
        errors,
        groupSecretsManager: {
          status: 'DEPROVISIONING',
        },
        __typename: 'GroupSecretsManagerDeprovisionPayload',
      },
    },
  };
};

export const MOCK_GROUPS_API = [
  {
    id: 11,
    value: 11,
    avatarUrl: '/uploads/-/system/user/avatar/3/avatar.png',
    name: 'Organization',
    username: 'organization',
  },
  {
    id: 22,
    value: 22,
    avatarUrl: '/uploads/-/system/user/avatar/4/avatar.png',
    name: 'test-org',
    username: 'test-org',
  },
];

export const mockCreatePermissionResponse = {
  data: {
    secretsPermissionUpdate: {
      secretsPermission: {
        principal: {
          id: 1,
          type: 'Role',
          __typename: 'Principal',
        },
        actions: ['read', 'write'],
        __typename: TYPENAME_SECRET_PERMISSION,
      },
      errors: [],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
};

export const mockCreatePermissionErrorResponse = (errorMessage) => ({
  data: {
    secretsPermissionUpdate: {
      secretsPermission: null,
      errors: [errorMessage],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
});

export const mockDeletePermissionResponse = (errorMessage) => ({
  data: {
    secretsPermissionDelete: {
      errors: errorMessage ? [errorMessage] : [],
    },
  },
});

export const mockCreateGroupPermissionResponse = {
  data: {
    secretsPermissionUpdate: {
      secretsPermission: {
        principal: {
          id: 1,
          type: 'Role',
          __typename: 'Principal',
        },
        actions: ['read', 'write'],
        __typename: TYPENAME_SECRET_PERMISSION,
      },
      errors: [],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
};

export const mockCreateGroupPermissionErrorResponse = (errorMessage) => ({
  data: {
    secretsPermissionUpdate: {
      secretsPermission: null,
      errors: [errorMessage],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
});

export const mockDeleteGroupPermissionResponse = (errorMessage) => ({
  data: {
    secretsPermissionDelete: {
      errors: errorMessage ? [errorMessage] : [],
    },
  },
});

export const ROOT_USER_DETAILS = {
  id: 'gid://gitlab/User/1',
  username: 'root',
  name: 'Administrator',
  avatarUrl:
    'https://www.gravatar.com/avatar/85366df1bc2e8979432dbdafee989bce82734d876698ec4c6cd847b9ae1fedf2?s=80&d=identicon',
  webUrl: 'http://gdk.test:3000/root',
};

export const mockProjectMembersQueryResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      projectMembers: {
        nodes: [
          {
            id: 'gid://gitlab/ProjectMember/1',
            user: {
              ...ROOT_USER_DETAILS,
              __typename: 'UserCore',
            },
          },
          {
            id: 'gid://gitlab/ProjectMember/2',
            user: {
              id: 'gid://gitlab/User/2',
              name: 'John Doe',
              username: 'john.doe',
              avatarUrl: '/uploads/-/system/user/avatar/2/avatar.png',
              __typename: 'UserCore',
            },
          },
        ],
      },
    },
  },
};

export const mockGroupMembersQueryResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      users: {
        pageInfo: {
          hasNextPage: false,
          endCursor: null,
          startCursor: null,
        },
        nodes: [
          {
            id: 'gid://gitlab/GroupMember/1',
            user: {
              ...ROOT_USER_DETAILS,
              webPath: '/root',
              __typename: 'UserCore',
              status: null,
            },
          },
          {
            id: 'gid://gitlab/GroupMember/2',
            user: {
              id: 'gid://gitlab/User/2',
              name: 'John Doe',
              username: 'john.doe',
              avatarUrl: '/uploads/-/system/user/avatar/2/avatar.png',
              webUrl: 'http://gdk.test:3000/john.doe',
              webPath: '/john.doe',
              __typename: 'UserCore',
              status: null,
            },
          },
        ],
      },
    },
  },
};

const SECONDARY_USER_DETAILS = {
  id: 'gid://gitlab/User/4',
  username: 'lonnie',
  name: 'Lon Lonnie',
  avatarUrl:
    'https://www.gravatar.com/avatar/1e8e3e4b8471a36396bee959a2c31f6fd03ae08a2560bab45205fa795f79f4cf?s=80&d=identicon',
  webUrl: 'http://gdk.test:3000/lonnie',
};

const OWNER_PRINCIPAL = {
  id: 50,
  type: 'ROLE',
  userRoleId: null,
  user: null,
  group: null,
};

const ROLE_PRINCIPAL = {
  id: 20,
  type: 'ROLE',
  userRoleId: null,
  user: null,
  group: null,
};

const GROUP_PRINCIPAL = {
  id: 22,
  type: 'GROUP',
  userRoleId: null,
  user: null,
  group: {
    id: 'gid://gitlab/Group/22',
    name: 'Toolbox',
    avatarUrl: null,
    webUrl: 'http://gdk.test:3000/groups/toolbox',
  },
};

const USER_PRINCIPAL = {
  id: 49,
  type: 'USER',
  userRoleId: 40,
  user: {
    id: 'gid://gitlab/User/49',
    username: 'kristina.moen',
    name: 'Ginny McGlynn',
    avatarUrl:
      'https://www.gravatar.com/avatar/c491e205f3fc6673ee13fe84efdcad77301b884bdaa5274deb72dafd9c03108e?s=80&d=identicon',
    webUrl: 'http://gdk.test:3000/kristina.moen',
  },
  group: null,
};

export const OWNER_PERMISSION_NODE = {
  expiredAt: null,
  grantedBy: null,
  actions: ['READ', 'WRITE', 'DELETE'],
  principal: OWNER_PRINCIPAL,
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const ROLE_PERMISSION_NODE = {
  expiredAt: '2035-01-01',
  grantedBy: ROOT_USER_DETAILS,
  actions: ['READ', 'WRITE'],
  principal: ROLE_PRINCIPAL,
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const GROUP_PERMISSION_NODE = {
  expiredAt: '2035-01-01',
  grantedBy: SECONDARY_USER_DETAILS,
  actions: ['READ', 'WRITE', 'DELETE'],
  principal: GROUP_PRINCIPAL,
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const USER_PERMISSION_NODE = {
  expiredAt: null,
  grantedBy: ROOT_USER_DETAILS,
  actions: ['READ', 'READ_VALUE', 'DELETE'],
  principal: USER_PRINCIPAL,
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const GROUP_OWNER_PERMISSION_NODE = {
  expiredAt: null,
  grantedBy: null,
  actions: ['READ', 'WRITE', 'DELETE'],
  principal: OWNER_PRINCIPAL,
  group: {
    id: 'gid://gitlab/Group/24',
  },
};

export const GROUP_ROLE_PERMISSION_NODE = {
  expiredAt: '2035-01-01',
  grantedBy: ROOT_USER_DETAILS,
  actions: ['READ', 'WRITE'],
  principal: ROLE_PRINCIPAL,
  group: {
    id: 'gid://gitlab/Group/24',
  },
};

export const GROUP_SUBGROUP_PERMISSION_NODE = {
  expiredAt: '2035-01-01',
  grantedBy: SECONDARY_USER_DETAILS,
  actions: ['READ', 'WRITE', 'DELETE'],
  principal: GROUP_PRINCIPAL,
  group: {
    id: 'gid://gitlab/Group/24',
  },
};

export const GROUP_USER_PERMISSION_NODE = {
  expiredAt: null,
  grantedBy: ROOT_USER_DETAILS,
  actions: ['READ', 'DELETE'],
  principal: USER_PRINCIPAL,
  group: {
    id: 'gid://gitlab/Group/24',
  },
};

export const mockPermissionsQueryResponse = (errors = undefined) => ({
  data: {
    errors,
    secretsPermissions: {
      nodes: [
        OWNER_PERMISSION_NODE,
        ROLE_PERMISSION_NODE,
        GROUP_PERMISSION_NODE,
        USER_PERMISSION_NODE,
      ],
    },
  },
});

export const mockGroupPermissionsQueryResponse = (errors = undefined) => ({
  data: {
    errors,
    secretsPermissions: {
      nodes: [
        GROUP_OWNER_PERMISSION_NODE,
        GROUP_ROLE_PERMISSION_NODE,
        GROUP_SUBGROUP_PERMISSION_NODE,
        GROUP_USER_PERMISSION_NODE,
      ],
    },
  },
});
