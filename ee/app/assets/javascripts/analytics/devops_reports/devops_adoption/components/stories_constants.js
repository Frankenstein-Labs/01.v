/* eslint-disable @gitlab/require-i18n-strings */

export const mockNamespace = {
  __typename: 'Namespace',
  fullName: 'Fake group',
  fullPath: 'fake-group',
  id: 'gid://fake/Group/101',
};

export const mockDevopsAdoptionNamespace = {
  __typename: 'DevopsAdoptionEnabledNamespace',
  id: 'gid://fake/Analytics::DevopsAdoption::EnabledNamespace/2',
  latestSnapshot: {
    __typename: 'DevopsAdoptionSnapshot',
    issueOpened: true,
    mergeRequestOpened: true,
    mergeRequestApproved: false,
    runnerConfigured: false,
    pipelineSucceeded: false,
    deploySucceeded: false,
    recordedAt: '2024-10-01T01:00:21Z',
    codeOwnersUsedCount: 1,
    sastEnabledCount: 0,
    dastEnabledCount: 0,
    coverageFuzzingEnabledCount: 0,
    dependencyScanningEnabledCount: 0,
  },
  namespace: mockNamespace,
};

export const mockDevopsOverviewChartResponse = {
  data: {
    devopsAdoptionEnabledNamespaces: {
      nodes: [
        {
          id: 'gid://gitlab/Analytics::DevopsAdoption::EnabledNamespace/3',
          namespace: {
            id: 'fake-group',
            __typename: 'Namespace',
          },
          snapshots: {
            nodes: [
              {
                endTime: '2024-08-31T23:59:59Z',
                issueOpened: false,
                mergeRequestOpened: false,
                mergeRequestApproved: false,
                runnerConfigured: false,
                pipelineSucceeded: false,
                deploySucceeded: false,
                recordedAt: '2024-09-03T01:00:17Z',
                codeOwnersUsedCount: 1,
                sastEnabledCount: 0,
                dastEnabledCount: 0,
                coverageFuzzingEnabledCount: 0,
                dependencyScanningEnabledCount: 0,
                __typename: 'DevopsAdoptionSnapshot',
              },
              {
                endTime: '2024-07-31T23:59:59Z',
                issueOpened: false,
                mergeRequestOpened: false,
                mergeRequestApproved: false,
                runnerConfigured: false,
                pipelineSucceeded: false,
                deploySucceeded: false,
                recordedAt: '2024-08-02T01:00:28Z',
                codeOwnersUsedCount: 1,
                sastEnabledCount: 0,
                dastEnabledCount: 0,
                coverageFuzzingEnabledCount: 0,
                dependencyScanningEnabledCount: 0,
                __typename: 'DevopsAdoptionSnapshot',
              },
              {
                endTime: '2024-06-30T23:59:59Z',
                issueOpened: false,
                mergeRequestOpened: false,
                mergeRequestApproved: false,
                runnerConfigured: false,
                pipelineSucceeded: false,
                deploySucceeded: false,
                recordedAt: '2024-07-12T10:49:31Z',
                codeOwnersUsedCount: 1,
                sastEnabledCount: 0,
                dastEnabledCount: 0,
                coverageFuzzingEnabledCount: 0,
                dependencyScanningEnabledCount: 0,
                __typename: 'DevopsAdoptionSnapshot',
              },
            ],
            __typename: 'DevopsAdoptionSnapshotConnection',
          },
          __typename: 'DevopsAdoptionEnabledNamespace',
        },
      ],
      __typename: 'DevopsAdoptionEnabledNamespaceConnection',
    },
  },
};
