export const mockGroupMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/3',
      memberRoles: {
        nodes: [
          {
            baseAccessLevel: {
              integerValue: 10,
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/100',
            name: 'My role group 1',
            description: 'My role group 1 description',
            membersCount: 0,
            editPath: 'edit/path',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
              ],
            },
            __typename: 'MemberRole',
          },
          {
            baseAccessLevel: {
              integerValue: 20,
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/101',
            name: 'My role group 2',
            description: 'My role group 2 description',
            membersCount: 0,
            editPath: 'edit/path',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
              ],
            },
            __typename: 'MemberRole',
          },
        ],
        __typename: 'MemberRoleConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockProjectMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Project/12',
      memberRoles: {
        nodes: [
          {
            baseAccessLevel: {
              integerValue: 10,
              stringValue: 'GUEST',
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/103',
            name: 'My role project 1',
            description: 'My role project 1 description',
            membersCount: 0,
            editPath: 'edit/path',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
              ],
            },
            __typename: 'MemberRole',
          },
        ],
        __typename: 'MemberRoleConnection',
      },
    },
  },
};

export const mockInstanceMemberRoles = {
  data: {
    memberRoles: {
      nodes: [
        {
          baseAccessLevel: {
            integerValue: 10,
            stringValue: 'GUEST',
            __typename: 'AccessLevel',
          },
          id: 'gid://gitlab/MemberRole/104',
          name: 'My role instance 1',
          description: 'My role instance 1 description',
          membersCount: 0,
          editPath: 'edit/path',
          enabledPermissions: {
            nodes: [
              {
                name: 'Read code',
                value: 'READ_CODE',
              },
            ],
          },
          __typename: 'MemberRole',
        },
      ],
      __typename: 'MemberRoleConnection',
    },
  },
};

export const GROUPS_INVITATIONS_PATH = '/api/v4/groups/1/invitations';

const MEMBER_PENDING_APPROVAL = {
  status: 'success',
  queued_users: {
    'email@example.com': 'Request queued for administrator approval.',
  },
};

const ERROR_AND_PENDING_APPROVAL = {
  status: 'error',
  queued_users: {
    'email@example.com': 'Request queued for administrator approval.',
  },
  message: {
    john_smith: 'Something is wrong for this member.',
  },
};

export const invitationsApiResponse = {
  MEMBER_PENDING_APPROVAL,
  ERROR_AND_PENDING_APPROVAL,
};
