export const mockComponentUsages = [
  {
    project: {
      id: 'gid://gitlab/Project/1',
      nameWithNamespace: 'Group / Project 1',
      webPath: 'http://gdk.test:3000/group/project-1',
    },
    componentsUsed: [
      {
        component: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Component/1',
          name: 'component-1',
        },
        version: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Version/1',
          name: '1.0.0',
        },
        lastUsedDate: '2024-01-15',
        outdated: false,
      },
    ],
  },
];

export const mockOutdatedComponentUsages = [
  {
    project: {
      id: 'gid://gitlab/Project/2',
      nameWithNamespace: 'Group / Project 2',
      webPath: 'http://gdk.test:3000/group/project-2',
    },
    componentsUsed: [
      {
        component: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Component/2',
          name: 'component-2',
        },
        version: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Version/2',
          name: '0.9.0',
        },
        lastUsedDate: '2024-01-10',
        outdated: true,
      },
    ],
  },
];

export const mockMultipleComponentUsages = [
  {
    project: {
      id: 'gid://gitlab/Project/3',
      nameWithNamespace: 'Group / Project 3',
      webPath: 'http://gdk.test:3000/group/project-3',
    },
    componentsUsed: [
      {
        component: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Component/3',
          name: 'component-a',
        },
        version: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Version/3',
          name: '2.0.0',
        },
        lastUsedDate: '2024-01-20',
        outdated: false,
      },
      {
        component: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Component/4',
          name: 'component-b',
        },
        version: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Version/4',
          name: '1.5.0',
        },
        lastUsedDate: '2024-01-18',
        outdated: false,
      },
    ],
  },
];

export const mockNullProjectComponentUsages = [
  {
    project: null,
    componentsUsed: [
      {
        component: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Component/5',
          name: 'component-5',
        },
        version: {
          id: 'gid://gitlab/Ci::Catalog::Resources::Version/5',
          name: '1.2.0',
        },
        lastUsedDate: '2024-01-12',
        outdated: false,
      },
    ],
  },
];

export const mockPageInfo = {
  __typename: 'PageInfo',
  startCursor: 'eyJpZCI6IjEifQ',
  endCursor: 'eyJpZCI6IjIwIn0',
  hasNextPage: true,
  hasPreviousPage: false,
};

export const mockPageInfoPage2 = {
  __typename: 'PageInfo',
  startCursor: 'eyJpZCI6IjIxIn0',
  endCursor: 'eyJpZCI6IjQwIn0',
  hasNextPage: false,
  hasPreviousPage: true,
};

export const mockPermissionsData = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      userPermissions: {
        readProject: true,
        readProjectComponentUsages: true,
      },
      licensedFeatureAvailability: {
        available: true,
      },
    },
  },
};

export const mockUsageData = {
  data: {
    ciCatalogResource: {
      id: 'gid://gitlab/Ci::Catalog::Resource/1',
      webPath: '/root/my-component',
      projectComponentUsages: {
        nodes: mockComponentUsages,
        pageInfo: mockPageInfo,
      },
    },
  },
};

export const mockUsageDataPage2 = {
  data: {
    ciCatalogResource: {
      id: 'gid://gitlab/Ci::Catalog::Resource/1',
      webPath: '/root/my-component',
      projectComponentUsages: {
        nodes: mockOutdatedComponentUsages,
        pageInfo: mockPageInfoPage2,
      },
    },
  },
};

export const mockEmptyUsageData = {
  data: {
    ciCatalogResource: {
      id: 'gid://gitlab/Ci::Catalog::Resource/1',
      webPath: '/root/my-component',
      projectComponentUsages: {
        nodes: [],
        pageInfo: {
          __typename: 'PageInfo',
          startCursor: null,
          endCursor: null,
          hasNextPage: false,
          hasPreviousPage: false,
        },
      },
    },
  },
};
