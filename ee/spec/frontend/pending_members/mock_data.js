import {
  HEADER_TOTAL_ENTRIES,
  HEADER_PAGE_NUMBER,
  HEADER_ITEMS_PER_PAGE,
} from 'ee/pending_members/constants';

export const mockDataMembers = {
  data: [
    {
      id: 177,
      name: '334050-1 334050-1',
      username: '334050-1',
      email: '334050-1@gitlab.com',
      web_url: 'http://127.0.0.1:3000/334050-1',
      avatar_url:
        'https://www.gravatar.com/avatar/9987bae8f71451bb2d422d0596367b25?s=80&d=identicon',
      approved: false,
      invited: false,
    },
    {
      id: 178,
      email: 'first-invite@gitlab.com',
      avatar_url:
        'https://www.gravatar.com/avatar/8bad6be3d5070e7f7865d91a50f44f1f?s=80&d=identicon',
      approved: false,
      invited: true,
    },
  ],
  headers: {
    [HEADER_TOTAL_ENTRIES]: '3',
    [HEADER_PAGE_NUMBER]: '1',
    [HEADER_ITEMS_PER_PAGE]: '1',
  },
};

export const mockDataNoMembers = {
  data: [],
  headers: {
    [HEADER_TOTAL_ENTRIES]: '0',
    [HEADER_PAGE_NUMBER]: '1',
    [HEADER_ITEMS_PER_PAGE]: '1',
  },
};

export const mockInvitedApprovedMember = {
  id: 179,
  email: 'second-invite@gitlab.com',
  avatar_url: 'https://www.gravatar.com/avatar/c96806e80ab8c4ea4c668d795fcfed0f?s=80&d=identicon',
  approved: true,
  invited: true,
};

export const pendingMembersResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/35',
      pendingMembers: {
        nodes: [
          {
            id: 'gid://gitlab/GroupMember/98',
            email: 'pending_1@gmail.com',
            invited: true,
            avatarUrl:
              'https://www.gravatar.com/avatar/f642d140d8eca76c2a0e20cd7827dbe182681638b310e4dcb729640e0281175b?s=80&d=identicon',
            webUrl: 'https://gitlab.com/pending_1',
            approved: true,
            name: 'John Doe',
            __typename: 'PendingGroupMember',
          },
          {
            id: 'gid://gitlab/GroupMember/100',
            email: 'pending_3@gmail.com',
            invited: true,
            avatarUrl:
              'https://www.gravatar.com/avatar/26ff88e0fdba111305d7a8a018ed41554c413a44c8bd4c6666e3e20126bf1f4a?s=80&d=identicon',
            webUrl: 'https://gitlab.com/pending_3',
            approved: false,
            name: 'Admin',
            __typename: 'PendingGroupMember',
          },
          {
            id: 'gid://gitlab/GroupMember/101',
            email: 'pending_4@gmail.com',
            invited: true,
            avatarUrl:
              'https://www.gravatar.com/avatar/26ff88e0fdba111305d7a8a018ed41554c413a44c8bd4c6666e3e20126bf1f4a?s=80&d=identicon',
            webUrl: 'https://gitlab.com/pending_4',
            approved: false,
            name: 'Jane Doe',
            __typename: 'PendingGroupMember',
          },
        ],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'MTE',
          endCursor: 'MjA',
          __typename: 'PageInfo',
        },
        __typename: 'PendingGroupMemberConnection',
      },
      __typename: 'Group',
    },
  },
};

export const pendingMembersResponseEmpty = {
  data: {
    group: {
      id: 'gid://gitlab/Group/35',
      pendingMembers: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: 'MTE',
          endCursor: 'MjA',
          __typename: 'PageInfo',
        },
        __typename: 'PendingGroupMemberConnection',
      },
      __typename: 'Group',
    },
  },
};
