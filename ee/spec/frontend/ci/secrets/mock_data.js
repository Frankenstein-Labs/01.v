export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/20',
      environments: {
        __typename: 'EnvironmentConnection',
        nodes: [
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/56',
            name: 'project_env_development',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/55',
            name: 'project_env_production',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/57',
            name: 'project_env_staging',
          },
        ],
      },
    },
  },
};

export const mockGroupEnvironments = {
  data: {
    group: {
      __typename: 'Group',
      id: 'gid://gitlab/Group/96',
      environmentScopes: {
        __typename: 'CiGroupEnvironmentScopeConnection',
        nodes: [
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_development',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_production',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_staging',
          },
        ],
      },
    },
  },
};

export const mockProjectBranches = {
  data: {
    project: {
      id: 'gid://gitlab/Project/19',
      repository: {
        branchNames: ['dev', 'main', 'production', 'staging'],
        __typename: 'Repository',
      },
      __typename: 'Project',
    },
  },
};

export const mockProjectSecretsData = [
  {
    node: {
      branch: '*',
      createdAt: '2025-01-15T10:00:00Z',
      description: 'This is the first secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: {
        rotationIntervalDays: 7,
        status: 'APPROACHING',
        __typename: 'SecretRotationInfo',
      },
      name: 'SECRET_1',
      status: 'COMPLETED',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    node: {
      branch: 'main',
      createdAt: '2025-02-10T14:30:00Z',
      description: 'This is the second secret',
      environment: 'canary',
      metadataVersion: 1,
      rotationInfo: {
        rotationIntervalDays: 7,
        status: 'OVERDUE',
        __typename: 'SecretRotationInfo',
      },
      name: 'SECRET_2',
      status: 'CREATE_STALE',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    node: {
      branch: 'main',
      createdAt: '2025-03-05T09:15:00Z',
      description: 'This is the third secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'SECRET_3',
      status: 'UPDATE_STALE',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    node: {
      branch: 'main',
      createdAt: '2025-04-20T16:45:00Z',
      description: 'This is the fourth secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'SECRET_4',
      status: 'CREATE_IN_PROGRESS',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    node: {
      branch: 'main',
      createdAt: '2025-05-12T11:00:00Z',
      description: 'This is the fifth secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'SECRET_5',
      status: 'UPDATE_IN_PROGRESS',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
];

export const mockGroupSecretsData = [
  {
    node: {
      createdAt: '2025-01-15T10:00:00Z',
      description: 'This is the first group secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: {
        rotationIntervalDays: 7,
        status: 'APPROACHING',
        __typename: 'SecretRotationInfo',
      },
      name: 'GROUP_SECRET_1',
      protected: true,
      status: 'COMPLETED',
      group: {
        id: 'gid://gitlab/Group/111',
        fullPath: 'gitlab-org',
        __typename: 'Group',
      },
      __typename: 'GroupSecret',
    },
    __typename: 'GroupSecretEdge',
  },
  {
    node: {
      createdAt: '2025-02-10T14:30:00Z',
      description: 'This is the second group secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: {
        rotationIntervalDays: 7,
        status: 'OVERDUE',
        __typename: 'SecretRotationInfo',
      },
      name: 'GROUP_SECRET_2',
      protected: true,
      status: 'CREATE_STALE',
      group: {
        id: 'gid://gitlab/Group/111',
        fullPath: 'gitlab-org',
        __typename: 'Group',
      },
      __typename: 'GroupSecret',
    },
    __typename: 'GroupSecretEdge',
  },
  {
    node: {
      createdAt: '2025-03-05T09:15:00Z',
      description: 'This is the third group secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'GROUP_SECRET_3',
      protected: false,
      status: 'UPDATE_STALE',
      group: {
        id: 'gid://gitlab/Group/111',
        fullPath: 'gitlab-org',
        __typename: 'Group',
      },
      __typename: 'GroupSecret',
    },
    __typename: 'GroupSecretEdge',
  },
  {
    node: {
      createdAt: '2025-04-20T16:45:00Z',
      description: 'This is the fourth group secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'GROUP_SECRET_4',
      protected: true,
      status: 'CREATE_IN_PROGRESS',
      group: {
        id: 'gid://gitlab/Group/111',
        fullPath: 'gitlab-org',
        __typename: 'Group',
      },
      __typename: 'GroupSecret',
    },
    __typename: 'GroupSecretEdge',
  },
  {
    node: {
      createdAt: '2025-05-12T11:00:00Z',
      description: 'This is the fifth group secret',
      environment: '*',
      metadataVersion: 1,
      rotationInfo: null,
      name: 'GROUP_SECRET_5',
      protected: false,
      status: 'UPDATE_IN_PROGRESS',
      group: {
        id: 'gid://gitlab/Group/111',
        fullPath: 'gitlab-org',
        __typename: 'Group',
      },
      __typename: 'GroupSecret',
    },
    __typename: 'GroupSecretEdge',
  },
];

export const mockProjectSecretsResponse = (edges = mockProjectSecretsData) => ({
  data: {
    secretsList: {
      edges,
      __typename: 'ProjectSecretConnection',
    },
  },
});

export const mockGroupSecretsResponse = (edges = mockGroupSecretsData) => ({
  data: {
    secretsList: {
      edges,
      __typename: 'GroupSecretConnection',
    },
  },
});

const mockSecretId = 44;

export const mockProjectSecret = ({ customSecret } = {}) => ({
  __typename: 'Secret',
  id: mockSecretId,
  branch: 'main',
  description: 'This is a project secret',
  environment: 'staging',
  metadataVersion: 1,
  name: 'PROJECT_SECRET',
  rotationInfo: null,
  status: 'COMPLETED',
  ...customSecret,
});

export const mockGroupSecret = ({ customSecret } = {}) => ({
  __typename: 'Secret',
  id: mockSecretId,
  description: 'This is a group secret',
  environment: 'staging',
  metadataVersion: 1,
  name: 'GROUP_SECRET',
  status: 'COMPLETED',
  rotationInfo: null,
  protected: true,
  ...customSecret,
});

export const mockEmptySecrets = {
  data: {
    projectSecrets: {
      edges: [],
      pageInfo: {
        endCursor: null,
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        __typename: 'PageInfo',
      },
      __typename: 'ProjectSecretConnection',
    },
  },
};

export const mockProjectCreateSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    secretCreate: {
      errors,
      __typename: 'ProjectSecretCreatePayload',
      projectSecret: {
        name: 'APP_PWD',
        description: 'This is a secret',
        ...customSecret,
        __typename: 'ProjectSecret',
      },
    },
  },
});

export const mockGroupCreateSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    secretCreate: {
      errors,
      __typename: 'GroupSecretCreatePayload',
      groupSecret: {
        name: 'APP_PWD',
        description: 'This is a secret',
        ...customSecret,
        __typename: 'GroupSecret',
      },
    },
  },
});

export const mockProjectUpdateSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    secretUpdate: {
      errors,
      __typename: 'ProjectSecretUpdatePayload',
      projectSecret: {
        name: 'APP_PWD',
        description: 'This is an edited secret',
        ...customSecret,
        __typename: 'ProjectSecret',
      },
    },
  },
});

export const mockGroupUpdateSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    secretUpdate: {
      errors,
      __typename: 'GroupSecretUpdatePayload',
      groupSecret: {
        name: 'APP_PWD',
        description: 'This is an edited secret',
        ...customSecret,
        __typename: 'GroupSecret',
      },
    },
  },
});

export const mockProjectSecretQueryResponse = ({ customSecret } = {}) => ({
  data: {
    secret: {
      __typename: 'ProjectSecret',
      ...mockProjectSecret({ customSecret }),
    },
  },
});

export const mockGroupSecretQueryResponse = ({ customSecret } = {}) => ({
  data: {
    secret: {
      __typename: 'GroupSecret',
      ...mockGroupSecret({ customSecret }),
    },
  },
});

export const openbaoHealthResponse = (healthy = true) => ({
  data: {
    openbaoHealth: healthy,
  },
});

export const secretManagerStatusResponse = (
  status,
  context = 'project',
  entity = { archived: false, markedForDeletion: false },
) => {
  if (context === 'group') {
    return {
      data: {
        secretsManager: {
          entity: {
            id: 'gid://gitlab/Group/96',
            ...entity,
          },
          status,
          __typename: 'GroupSecretsManager',
        },
      },
    };
  }

  return {
    data: {
      secretsManager: {
        entity: {
          id: 'gid://gitlab/Project/96',
          ...entity,
        },
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
  };
};

export const mockDeleteProjectSecretResponse = ({ error = undefined } = {}) => ({
  data: {
    deleteSecret: {
      errors: [error],
      __typename: 'ProjectSecretDeletePayload',
    },
  },
});

export const mockDeleteGroupSecretResponse = ({ error = undefined } = {}) => ({
  data: {
    deleteSecret: {
      errors: [error],
      __typename: 'GroupSecretDeletePayload',
    },
  },
});

export const mockEntitlement = (entitlement = {}) => ({
  state: 'TRIAL_ELIGIBLE',
  blockedReason: null,
  trialStartedAt: null,
  trialExpiresAt: null,
  creditsRemaining: 0,
  creditsTotal: 0,
  onDemandEnabled: true,
  ...entitlement,
});

export const entitlementResponse = (entitlement = {}) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/96',
      secretsManagerEntitlement: mockEntitlement(entitlement),
      __typename: 'Group',
    },
  },
});

export const enrollNamespaceSuccessResponse = () => ({
  data: {
    namespaceSecretsManagerEnroll: {
      enrollment: { namespace: { id: 'gid://gitlab/Group/96' } },
      errors: [],
      __typename: 'NamespaceSecretsManagerEnrollPayload',
    },
  },
});

export const enrollNamespaceAlreadyEnrolledResponse = () => ({
  data: {
    namespaceSecretsManagerEnroll: {
      enrollment: null,
      errors: ['Namespace is already enrolled.'],
      __typename: 'NamespaceSecretsManagerEnrollPayload',
    },
  },
});

export const enrollNamespaceErrorResponse = (errors = ['Not authorized']) => ({
  data: {
    namespaceSecretsManagerEnroll: {
      enrollment: null,
      errors,
      __typename: 'NamespaceSecretsManagerEnrollPayload',
    },
  },
});

export const startTrialSuccessResponse = () => ({
  data: {
    secretsManagerStartTrial: {
      entitlement: mockEntitlement({ state: 'TRIAL' }),
      errors: [],
      __typename: 'SecretsManagerStartTrialPayload',
    },
  },
});

export const startTrialErrorResponse = (errors = ['This group is not eligible']) => ({
  data: {
    secretsManagerStartTrial: {
      entitlement: null,
      errors,
      __typename: 'SecretsManagerStartTrialPayload',
    },
  },
});

export const enableSecretManagerResponse = ({
  context = 'project',
  status = 'PROVISIONING',
  errors = [],
} = {}) => {
  if (context === 'group') {
    return {
      data: {
        groupSecretsManagerInitialize: {
          errors,
          groupSecretsManager: errors.length ? null : { status, __typename: 'GroupSecretsManager' },
          __typename: 'GroupSecretsManagerInitializePayload',
        },
      },
    };
  }

  return {
    data: {
      projectSecretsManagerInitialize: {
        errors,
        projectSecretsManager: errors.length
          ? null
          : { status, __typename: 'ProjectSecretsManager' },
        __typename: 'ProjectSecretsManagerInitializePayload',
      },
    },
  };
};
