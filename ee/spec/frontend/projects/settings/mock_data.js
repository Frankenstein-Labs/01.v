export const accessLevelsMockResponse = {
  __typename: 'PushAccessLevelConnection',
  edges: [
    {
      __typename: 'PushAccessLevelEdge',
      node: {
        __typename: 'PushAccessLevel',
        accessLevel: 40,
        accessLevelDescription: 'Jona Langworth',
        group: null,
        user: {
          __typename: 'UserCore',
          id: '123',
          webUrl: 'test.com',
          name: 'peter',
          avatarUrl: 'test.com/user.png',
        },
        deployKey: null,
      },
    },
    {
      __typename: 'PushAccessLevelEdge',
      node: {
        __typename: 'PushAccessLevel',
        accessLevel: 40,
        accessLevelDescription: 'Key name',
        group: null,
        user: null,
        deployKey: {
          id: '14',
          title: 'Key name',
          user: {
            name: 'Jenny Smith',
            __typename: 'AccessLevelUser',
          },
          __typename: 'AccessLevelDeployKey',
        },
      },
    },
    {
      __typename: 'PushAccessLevelEdge',
      node: {
        __typename: 'PushAccessLevel',
        accessLevel: 40,
        accessLevelDescription: 'Maintainers',
        group: null,
        user: null,
      },
    },
  ],
};

export const accessLevelsMockResult = {
  total: 3,
  users: [
    {
      src: 'test.com/user.png',
      __typename: 'UserCore',
      id: '123',
      webUrl: 'test.com',
      name: 'peter',
      avatarUrl: 'test.com/user.png',
    },
  ],
  groups: [],
  memberRoles: [],
  roles: [40],
  deployKeys: [
    {
      __typename: 'AccessLevelDeployKey',
      id: '14',
      title: 'Key name',
      user: {
        name: 'Jenny Smith',
        __typename: 'AccessLevelUser',
      },
    },
  ],
};
