import { GROUP_VIEW_TYPE, PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';

export const getNamespacePagesDeploymentsMockData = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      name: 'Gitlab Org',
      projects: {
        nodes: [
          {
            id: 'gid://gitlab/Project/19',
            name: 'My HTML Page',
            fullPath: 'gitlab-org/my-html-page',
            avatarUrl: 'http://gdk.test:3000/uploads/-/system/project/avatar/19/gitlab_logo.png',
            pagesDeployments: {
              count: 3,
              pageInfo: {
                startCursor:
                  'eyJjcmVhdGVkX2F0IjoiMjAyNC0wNS0yMiAxMzozNzoyMi40MTk4MzcwMDAgKzAwMDAiLCJpZCI6IjQ4In0',
                endCursor:
                  'eyJjcmVhdGVkX2F0IjoiMjAyNC0wNS0yMiAxMzozNzoyMi40MTk4MzcwMDAgKzAwMDAiLCJpZCI6IjQ2In0',
                hasNextPage: false,
                hasPreviousPage: false,
                __typename: 'PageInfo',
              },
              nodes: [
                {
                  id: 'gid://gitlab/PagesDeployment/48',
                  active: true,
                  ciBuildId: '499',
                  createdAt: '2024-05-22T13:37:22Z',
                  deletedAt: null,
                  fileCount: 3,
                  pathPrefix: '_mr2019',
                  rootDirectory: 'public',
                  size: 1082,
                  updatedAt: '2024-08-07T13:14:10Z',
                  url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2019',
                  __typename: 'PagesDeployment',
                },
                {
                  id: 'gid://gitlab/PagesDeployment/47',
                  active: true,
                  ciBuildId: '499',
                  createdAt: '2024-05-22T13:37:22Z',
                  deletedAt: null,
                  fileCount: 3,
                  pathPrefix: '_mr2018',
                  rootDirectory: 'public',
                  size: 1082,
                  updatedAt: '2024-08-07T13:14:21Z',
                  url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2018',
                  __typename: 'PagesDeployment',
                },
                {
                  id: 'gid://gitlab/PagesDeployment/46',
                  active: true,
                  ciBuildId: '499',
                  createdAt: '2024-05-22T13:37:22Z',
                  deletedAt: null,
                  fileCount: 3,
                  pathPrefix: '_mr2017',
                  rootDirectory: 'public',
                  size: 1082,
                  updatedAt: '2024-08-07T13:14:26Z',
                  url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2017',
                  __typename: 'PagesDeployment',
                },
              ],
              __typename: 'PagesDeploymentConnection',
            },
            __typename: 'Project',
          },
          {
            id: 'gid://gitlab/Project/3',
            name: 'Gitlab Shell',
            fullPath: 'gitlab-org/gitlab-shell',
            avatarUrl: null,
            pagesDeployments: {
              count: 0,
              pageInfo: {
                startCursor: null,
                endCursor: null,
                hasNextPage: false,
                hasPreviousPage: false,
                __typename: 'PageInfo',
              },
              nodes: [],
              __typename: 'PagesDeploymentConnection',
            },
            __typename: 'Project',
          },
          {
            id: 'gid://gitlab/Project/2',
            name: 'Gitlab Test',
            fullPath: 'gitlab-org/gitlab-test',
            avatarUrl: null,
            pagesDeployments: {
              count: 1,
              pageInfo: {
                startCursor: null,
                endCursor: null,
                hasNextPage: false,
                hasPreviousPage: false,
                __typename: 'PageInfo',
              },
              nodes: [
                {
                  id: 'gid://gitlab/PagesDeployment/48',
                  active: true,
                  ciBuildId: '499',
                  createdAt: '2024-05-22T13:37:22Z',
                  deletedAt: null,
                  fileCount: 3,
                  pathPrefix: '_mr2019',
                  rootDirectory: 'public',
                  size: 1082,
                  updatedAt: '2024-08-07T13:14:10Z',
                  url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2019',
                  __typename: 'PagesDeployment',
                },
              ],
              __typename: 'PagesDeploymentConnection',
            },
            __typename: 'Project',
          },
        ],
        __typename: 'ProjectConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const getProjectPagesDeploymentsMockData = {
  data: {
    project: {
      id: 'gid://gitlab/Project/19',
      fullPath: 'my-group/my-project',
      pagesDeployments: {
        count: 3,
        pageInfo: {
          startCursor:
            'eyJjcmVhdGVkX2F0IjoiMjAyNC0wNS0yMiAxMzozNzoyMi40MTk4MzcwMDAgKzAwMDAiLCJpZCI6IjQ4In0',
          endCursor:
            'eyJjcmVhdGVkX2F0IjoiMjAyNC0wNS0yMiAxMzozNzoyMi40MTk4MzcwMDAgKzAwMDAiLCJpZCI6IjQ2In0',
          hasNextPage: false,
          hasPreviousPage: false,
          __typename: 'PageInfo',
        },
        nodes: [
          {
            id: 'gid://gitlab/PagesDeployment/48',
            active: true,
            ciBuildId: '499',
            createdAt: '2024-05-22T13:37:22Z',
            deletedAt: null,
            expiresAt: null,
            fileCount: 3,
            pathPrefix: '_mr2019',
            rootDirectory: 'public',
            size: 1082,
            updatedAt: '2024-08-07T13:14:10Z',
            url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2019',
            __typename: 'PagesDeployment',
          },
          {
            id: 'gid://gitlab/PagesDeployment/47',
            active: true,
            ciBuildId: '499',
            createdAt: '2024-05-22T13:37:22Z',
            deletedAt: null,
            expiresAt: null,
            fileCount: 3,
            pathPrefix: '_mr2018',
            rootDirectory: 'public',
            size: 1082,
            updatedAt: '2024-08-07T13:14:21Z',
            url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2018',
            __typename: 'PagesDeployment',
          },
          {
            id: 'gid://gitlab/PagesDeployment/46',
            active: true,
            ciBuildId: '499',
            createdAt: '2024-05-22T13:37:22Z',
            deletedAt: null,
            expiresAt: null,
            fileCount: 3,
            pathPrefix: '_mr2017',
            rootDirectory: 'public',
            size: 1082,
            updatedAt: '2024-08-07T13:14:26Z',
            url: 'http://my-html-page-root-57991cf20198ae591a39bb7e54a451c8050c28335f427.pages.gdk.test:3010/_mr2017',
            __typename: 'PagesDeployment',
          },
        ],
        __typename: 'PagesDeploymentConnection',
      },
      __typename: 'Project',
    },
  },
};

export const getEmptyNamespacePagesDeploymentsMockData = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      name: 'Gitlab Org',
      projects: {
        nodes: [],
        __typename: 'ProjectConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const getEmptyProjectPagesDeploymentsMockData = {
  data: {
    project: {
      id: 'gid://gitlab/Project/19',
      fullPath: 'my-group/my-project',
      pagesDeployments: {
        count: 0,
        pageInfo: {
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
          __typename: 'PageInfo',
        },
        nodes: [],
        __typename: 'PagesDeploymentConnection',
      },
      __typename: 'Project',
    },
  },
};

export const mockError = {
  errors: [
    {
      message: 'Some Error',
    },
  ],
};

export const deleteDeploymentError = {
  data: {
    deletePagesDeployment: {
      errors: ['some error'],
    },
  },
};

export const restoreDeploymentError = {
  data: {
    restorePagesDeployment: {
      errors: ['some error'],
    },
  },
};

export const deleteDeploymentSuccess = {
  data: {
    deletePagesDeployment: {
      errors: [],
      pagesDeployment: {
        id: '123',
        active: false,
        deletedAt: '2024-08-12T08:48:04Z',
        updatedAt: '2024-08-12T08:48:04Z',
        __typename: 'PagesDeployment',
      },
      __typename: 'DeletePagesDeploymentPayload',
    },
  },
};

export const restoreDeploymentSuccess = {
  data: {
    restorePagesDeployment: {
      errors: [],
      pagesDeployment: {
        id: '123',
        active: true,
        deletedAt: null,
        updatedAt: '2024-08-12T08:48:05Z',
        __typename: 'PagesDeployment',
      },
      __typename: 'RestorePagesDeploymentPayload',
    },
  },
};

export const groupViewStatsData = {
  fullPath: 'my-group',
  deploymentsLimit: 500,
  deploymentsCount: 50,
  projectDeploymentsCount: null,
  usesNamespaceDomain: null,
  deploymentsByProject: [
    {
      name: 'Project 1',
      count: 35,
    },
    {
      name: 'Project 2',
      count: 15,
    },
  ],
  domain: 'pages.example.com',
  viewType: GROUP_VIEW_TYPE,
};

export const projectViewNamespaceDomainStatsData = {
  fullPath: 'my-group/my-project',
  deploymentsLimit: 500,
  deploymentsCount: 60,
  projectDeploymentsCount: 17,
  deploymentsByProject: null,
  domain: 'pages.example.com',
  usesNamespaceDomain: true,
  viewType: PROJECT_VIEW_TYPE,
};

export const projectViewUniqueDomainStatsData = {
  ...projectViewNamespaceDomainStatsData,
  deploymentsCount: 19,
  projectDeploymentsCount: 19,
  usesNamespaceDomain: false,
};
