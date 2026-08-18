export const mockProjectsDoraMetrics = [
  {
    id: 'gid://gitlab/Project/992791',
    name: 'FlightA',
    avatarUrl: 'http://gdk.test:3000/avatarA',
    webUrl: 'http://gdk.test:3000/flightjs/FlightA',
    deployment_frequency: 0.33,
    change_failure_rate: 0.4,
    lead_time_for_changes: 86400,
    time_to_restore_service: 432000,
    trends: {
      deployment_frequency: -0.5,
      lead_time_for_changes: -0.6,
      time_to_restore_service: 0.6,
      change_failure_rate: 0.3,
    },
  },
  {
    id: 'gid://gitlab/Project/992792',
    name: 'FlightB',
    avatarUrl: 'http://gdk.test:3000/avatarB',
    webUrl: 'http://gdk.test:3000/flightjs/FlightB',
    deployment_frequency: 0.33,
    change_failure_rate: 0.4,
    lead_time_for_changes: 86400,
    time_to_restore_service: 432000,
    trends: {
      deployment_frequency: -0.5,
      lead_time_for_changes: -0.6,
      time_to_restore_service: 0.6,
      change_failure_rate: 0.3,
    },
  },
];

export const mockDataSourceResponses = [
  {
    data: {
      group: {
        projects: {
          count: 2,
        },
        dora: {
          projects: {
            pageInfo: {
              endCursor: 'page1',
              hasNextPage: true,
            },
            nodes: [
              {
                __typename: 'Project',
                id: 'gid://gitlab/Project/34',
                name: 'test',
                avatarUrl: null,
                webUrl: 'http://gdk.test:3000/flightjs/test',
                dora: {
                  __typename: 'Dora',
                  metrics: [
                    {
                      __typename: 'DoraMetric',
                      date: '2024-08-01',
                      deployment_frequency: null,
                      change_failure_rate: null,
                      lead_time_for_changes: null,
                      time_to_restore_service: null,
                    },
                    {
                      __typename: 'DoraMetric',
                      date: '2024-09-01',
                      deployment_frequency: null,
                      change_failure_rate: null,
                      lead_time_for_changes: null,
                      time_to_restore_service: null,
                    },
                  ],
                },
              },
            ],
          },
        },
      },
    },
  },
  {
    data: {
      group: {
        projects: {
          count: 2,
        },
        dora: {
          projects: {
            pageInfo: {
              endCursor: 'page2',
              hasNextPage: false,
            },
            nodes: [
              {
                __typename: 'Project',
                id: 'gid://gitlab/Project/7',
                name: 'Flight',
                avatarUrl: null,
                webUrl: 'http://gdk.test:3000/flightjs/Flight',
                dora: {
                  __typename: 'Dora',
                  metrics: [
                    {
                      __typename: 'DoraMetric',
                      date: '2024-08-01',
                      deployment_frequency: 0.6451612903225806,
                      change_failure_rate: 0.3,
                      lead_time_for_changes: 259200,
                      time_to_restore_service: 259200,
                    },
                    {
                      __typename: 'DoraMetric',
                      date: '2024-09-01',
                      deployment_frequency: 0.3333333333333333,
                      change_failure_rate: 0.4,
                      lead_time_for_changes: 86400,
                      time_to_restore_service: 432000,
                    },
                  ],
                },
              },
            ],
          },
        },
      },
    },
  },
];
