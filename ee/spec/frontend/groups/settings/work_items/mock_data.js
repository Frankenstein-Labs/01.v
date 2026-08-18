export const statusCounts = [
  {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/1',
      __typename: 'WorkItemStatus',
    },
    count: null,
    __typename: 'WorkItemStatusCount',
  },
  {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/2',
      __typename: 'WorkItemStatus',
    },
    count: null,
    __typename: 'WorkItemStatusCount',
  },
  {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/3',
      __typename: 'WorkItemStatus',
    },
    count: null,
    __typename: 'WorkItemStatusCount',
  },
  {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/4',
      __typename: 'WorkItemStatus',
    },
    count: null,
    __typename: 'WorkItemStatusCount',
  },
  {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/5',
      __typename: 'WorkItemStatus',
    },
    count: null,
    __typename: 'WorkItemStatusCount',
  },
];

export const mockNamespaceMetadata = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      linkPaths: {
        groupIssues: '/groups/gitlab-org/-/issues',
        __typename: 'GroupNamespaceLinks',
      },
      __typename: 'Namespace',
    },
  },
};

export const deleteStatusErrorResponse = {
  data: {
    lifecycleUpdate: {
      lifecycle: null,
      errors: ["Cannot delete status 'In progress' because it is in use"],
      __typename: 'LifecycleUpdatePayload',
    },
  },
};

export const mockLifecycles = [
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/37',
    name: 'Custom Lifecycle 23',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
      name: 'Karon Homenick',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/166',
      name: 'Mignon Kub',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
      name: 'Ronni Weissnat',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
        name: 'Karon Homenick',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/166',
        name: 'Mignon Kub',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
        name: 'Ronni Weissnat',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'canceled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/36',
    name: 'Custom Lifecycle 22',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/162',
      name: 'Fatima Kutch',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/163',
      name: 'Catharine Hermann',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/164',
      name: 'Ester Dietrich',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/162',
        name: 'Fatima Kutch',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/163',
        name: 'Catharine Hermann',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/164',
        name: 'Ester Dietrich',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'canceled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/35',
    name: 'Custom Lifecycle 21',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/159',
      name: 'Ella Sauer',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/160',
      name: 'Hanna Goyette',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/161',
      name: 'Vernice Runolfsson',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/159',
        name: 'Ella Sauer',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/160',
        name: 'Hanna Goyette',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/161',
        name: 'Vernice Runolfsson',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'canceled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/34',
    name: 'Custom Lifecycle 20',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/156',
      name: 'Ilana Lesch',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/157',
      name: 'Debra Rolfson',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/158',
      name: 'Camilla Stoltenberg',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/156',
        name: 'Ilana Lesch',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/157',
        name: 'Debra Rolfson',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/158',
        name: 'Camilla Stoltenberg',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'cancelled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/33',
    name: 'Custom Lifecycle 19',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/153',
      name: 'Emily Krajcik',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/154',
      name: 'Jong Gorczany',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/155',
      name: 'Shawn Berge',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/153',
        name: 'Emily Krajcik',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/154',
        name: 'Jong Gorczany',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/155',
        name: 'Shawn Berge',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'canceled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
  {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/32',
    name: 'Custom Lifecycle 18',
    defaultOpenStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/150',
      name: 'Tiana Okuneva',
      __typename: 'WorkItemStatus',
    },
    defaultClosedStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/151',
      name: 'Ranee Watsica',
      __typename: 'WorkItemStatus',
    },
    defaultDuplicateStatus: {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/152',
      name: 'Dalia Turcotte',
      __typename: 'WorkItemStatus',
    },
    workItemTypes: [],
    statuses: [
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/150',
        name: 'Tiana Okuneva',
        iconName: 'status-waiting',
        color: '#737278',
        description: null,
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/151',
        name: 'Ranee Watsica',
        iconName: 'status-success',
        color: '#108548',
        description: null,
        category: 'done',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/152',
        name: 'Dalia Turcotte',
        iconName: 'status-cancelled',
        color: '#DD2B0E',
        description: null,
        category: 'canceled',
        __typename: 'WorkItemStatus',
      },
    ],
    __typename: 'WorkItemLifecycle',
  },
];

export const mockCreateLifecycleResponse = {
  data: {
    lifecycleCreate: {
      lifecycle: {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/50',
        name: 'Name 24',
        statuses: [
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
            name: 'Triage',
            iconName: 'status-neutral',
            color: '#995715',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/87',
            name: 'To do',
            iconName: 'status-waiting',
            color: '#737278',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/88',
            name: 'In progress',
            iconName: 'status-running',
            color: '#1f75cb',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/89',
            name: 'Done',
            iconName: 'status-success',
            color: '#108548',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/90',
            name: "Won't do",
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/91',
            name: 'Duplicate',
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            __typename: 'WorkItemStatus',
          },
        ],
        defaultOpenStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/87',
          name: 'To do',
          __typename: 'WorkItemStatus',
        },
        defaultClosedStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/89',
          name: 'Done',
          __typename: 'WorkItemStatus',
        },
        defaultDuplicateStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/91',
          name: 'Duplicate',
          __typename: 'WorkItemStatus',
        },
        workItemTypes: [],
        __typename: 'WorkItemLifecycle',
      },
      errors: [],
      __typename: 'LifecycleCreatePayload',
    },
  },
};

export const mockDefaultLifecycleTemplateReponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      lifecycleTemplates: [
        {
          id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Lifecycle/Default',
          name: 'Default',
          workItemTypes: [],
          defaultOpenStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/To+do',
            name: 'To do',
            __typename: 'WorkItemStatus',
          },
          defaultClosedStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/Done',
            name: 'Done',
            __typename: 'WorkItemStatus',
          },
          defaultDuplicateStatus: {
            id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/Duplicate',
            name: 'Duplicate',
            __typename: 'WorkItemStatus',
          },
          statuses: [
            {
              id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/To+do',
              name: 'To do',
              iconName: 'status-waiting',
              color: '#737278',
              category: 'to_do',
              description: null,
              __typename: 'WorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/In+progress',
              name: 'In progress',
              iconName: 'status-running',
              color: '#1f75cb',
              category: 'in_progress',
              description: null,
              __typename: 'WorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/Done',
              name: 'Done',
              iconName: 'status-success',
              color: '#108548',
              category: 'done',
              description: null,
              __typename: 'WorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/Won%27t+do',
              name: "Won't do",
              iconName: 'status-cancelled',
              color: '#DD2B0E',
              category: 'canceled',
              description: null,
              __typename: 'WorkItemStatus',
            },
            {
              id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/Duplicate',
              name: 'Duplicate',
              iconName: 'status-cancelled',
              color: '#DD2B0E',
              category: 'canceled',
              description: null,
              __typename: 'WorkItemStatus',
            },
          ],
          __typename: 'WorkItemLifecycle',
        },
      ],
      __typename: 'Namespace',
    },
  },
};

const mockDefaultLifecycle = {
  ...mockDefaultLifecycleTemplateReponse.data.namespace.lifecycleTemplates[0],
};
export { mockDefaultLifecycle };

export const mockStatusesResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/24',
      statuses: {
        nodes: [
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/247',
            name: 'In progress 3',
            iconName: 'status-running',
            color: '#1f75cb',
            category: 'in_progress',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/246',
            name: 'In progress 2',
            iconName: 'status-running',
            color: '#1f75cb',
            category: 'in_progress',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/245',
            name: 'To do 2',
            iconName: 'status-waiting',
            color: '#737278',
            category: 'to_do',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/244',
            name: 'Triage 6',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/243',
            name: 'Triage 5',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/242',
            name: 'Triage 4',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/241',
            name: 'Triage 3',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/240',
            name: 'Triage 2',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/239',
            name: "Won't do",
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            category: 'canceled',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/86',
            name: 'Another one',
            iconName: 'status-cancelled',
            color: '#dd2b0e',
            category: 'canceled',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/85',
            name: 'Triage',
            iconName: 'status-neutral',
            color: '#995715',
            category: 'triage',
            description: 'Description 2',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/72',
            name: 'Duplicate',
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            category: 'canceled',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/70',
            name: 'Done',
            iconName: 'status-success',
            color: '#108548',
            category: 'done',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/69',
            name: 'In progress',
            iconName: 'status-running',
            color: '#1f75cb',
            category: 'in_progress',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/68',
            name: 'To do',
            iconName: 'status-waiting',
            color: '#737278',
            category: 'to_do',
            description: null,
            __typename: 'WorkItemStatus',
          },
        ],
        __typename: 'WorkItemStatusConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const removeLifecycleSuccessResponse = {
  data: {
    lifecycleDelete: {
      errors: [],
      lifecycle: null,
      __typename: 'LifecycleDeletePayload',
    },
  },
};
