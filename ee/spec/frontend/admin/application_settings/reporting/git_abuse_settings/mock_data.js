export const mockUser1 = {
  __typename: 'UserCore',
  id: 'gid://gitlab/User/1',
  avatarUrl: '/avatar1',
  name: 'Administrator',
  username: 'root',
  webUrl: '/root',
  webPath: '/root',
};

export const mockUser2 = {
  __typename: 'UserCore',
  id: 'gid://gitlab/User/2',
  avatarUrl: '/avatar2',
  name: 'Rookie',
  username: 'rookie',
  webUrl: '/rookie',
  webPath: '/rookie',
};

export const getUsersResponse = {
  data: {
    users: {
      __typename: 'UserCoreConnection',
      nodes: [mockUser1],
    },
  },
};

export const searchUsersResponse = {
  data: {
    users: {
      __typename: 'UserCoreConnection',
      nodes: [mockUser1, mockUser2],
    },
  },
};

export const groupMembersResponse = {
  data: {
    namespace: {
      id: '1',
      __typename: 'Group',
      users: {
        nodes: [
          {
            id: 'user-1',
            user: {
              ...mockUser1,
              status: {
                availability: 'BUSY',
              },
              duoStatus: {
                disabled: false,
                disabledReason: '',
              },
            },
          },
          {
            id: 'user-2',
            user: {
              ...mockUser2,
              status: {
                availability: 'BUSY',
              },
              duoStatus: {
                disabled: false,
                disabledReason: '',
              },
            },
          },
        ],
        pageInfo: {
          hasNextPage: false,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
          __typename: 'PageInfo',
        },
      },
    },
  },
};
