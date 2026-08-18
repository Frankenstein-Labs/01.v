export const selfManagedUsersQueuedForRolePromotion = {
  data: {
    selfManagedUsersQueuedForRolePromotion: {
      nodes: [
        {
          user: {
            id: 'gid://gitlab/User/21',
            name: 'Geraldo Harvey',
            username: 'jacquelin',
            avatarUrl:
              'https://www.gravatar.com/avatar/e2f720a993543710d1b5600e15079f2238652e8879fdd649449dd3ab3fc63540?s=80\u0026d=identicon',
            webUrl: 'http://localhost:3000/jacquelin',
            email: null,
            lastActivityOn: '2023-11-03',
            __typename: 'UserCore',
          },
          newAccessLevel: {
            stringValue: 'DEVELOPER',
            __typename: 'AccessLevel',
          },
          __typename: 'UsersQueuedForRolePromotion',
        },
        {
          user: {
            id: 'gid://gitlab/User/29',
            name: 'test test',
            username: 'test4',
            avatarUrl:
              'https://www.gravatar.com/avatar/98df8d46f118f8bef552b0ec0a3d729466a912577830212a844b73960777ac56?s=80\u0026d=identicon',
            webUrl: 'http://localhost:3000/test4',
            email: null,
            lastActivityOn: null,
            __typename: 'UserCore',
          },
          newAccessLevel: {
            stringValue: 'DEVELOPER',
            __typename: 'AccessLevel',
          },
          __typename: 'UsersQueuedForRolePromotion',
        },
        {
          user: {
            id: 'gid://gitlab/User/32',
            name: 'over_the_limit test',
            username: 'over_the_limit',
            avatarUrl:
              'https://www.gravatar.com/avatar/c41f0148f1d395d6612f8e1a9b6c13f7d4242811f32073bfecd5af7367cbd9cd?s=80\u0026d=identicon',
            webUrl: 'http://localhost:3000/over_the_limit',
            email: null,
            lastActivityOn: null,
            __typename: 'UserCore',
          },
          newAccessLevel: {
            stringValue: 'DEVELOPER',
            __typename: 'AccessLevel',
          },
          __typename: 'UsersQueuedForRolePromotion',
        },
        {
          user: {
            id: 'gid://gitlab/User/33',
            name: 'test_4 test',
            username: 'test_4',
            avatarUrl:
              'https://www.gravatar.com/avatar/c9a2ea38c1c78076dab8c3cfabfa070f63d3f22b382cb2fba8526238d14dc844?s=80\u0026d=identicon',
            webUrl: 'http://localhost:3000/test_4',
            email: null,
            lastActivityOn: '2024-04-01',
            __typename: 'UserCore',
          },
          newAccessLevel: {
            stringValue: 'DEVELOPER',
            __typename: 'AccessLevel',
          },
          __typename: 'UsersQueuedForRolePromotion',
        },
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor:
          'eyJ1c2VyX2lkIjoiMjEiLCJuZXdfYWNjZXNzX2xldmVsIjoiMzAiLCJjcmVhdGVkX2F0IjoiMjAyNC0wNS0zMSAxMDoyNzo0MC40MzgzMDIwMDAgKzAwMDAiLCJpZCI6IjE4In0',
        endCursor:
          'eyJ1c2VyX2lkIjoiMzMiLCJuZXdfYWNjZXNzX2xldmVsIjoiMzAiLCJjcmVhdGVkX2F0IjoiMjAyNC0wNS0zMSAxMDoyNzoyMy4yODc0ODIwMDAgKzAwMDAiLCJpZCI6IjE2In0',
        __typename: 'PageInfo',
      },
      __typename: 'UsersQueuedForRolePromotionConnection',
    },
  },
};

export const processUserLicenseSeatRequestMutationSuccess = {
  data: {
    processUserBillablePromotionRequest: {
      errors: [],
      result: 'SUCCESS',
    },
  },
};

export const processUserLicenseSeatRequestMutationPartialSuccess = {
  data: {
    processUserBillablePromotionRequest: {
      errors: [],
      result: 'PARTIAL_SUCCESS',
    },
  },
};

export const FAILURE_REASON = 'Some error occured';
export const processUserLicenseSeatRequestMutationFailure = {
  data: {
    processUserBillablePromotionRequest: {
      errors: [FAILURE_REASON],
      result: 'FAILURE',
    },
  },
};

export const defaultProvide = {
  paths: {
    adminUser: '///',
  },
};
