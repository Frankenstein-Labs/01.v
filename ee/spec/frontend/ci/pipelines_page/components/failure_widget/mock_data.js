export const failedJobsMock = {
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      pipeline: {
        id: 'gid://gitlab/Ci::Pipeline/1235',
        active: false,
        troubleshootJobWithAi: true,
        __typename: 'Pipeline',
        jobs: {
          count: 1,
          nodes: [
            {
              id: 'gid://gitlab/Ci::Build/12230',
              allowFailure: false,
              detailedStatus: {
                id: 'failed-12230-12230',
                detailsPath: '/root/ci-project/-/jobs/12230',
                group: 'failed',
                icon: 'status_failed',
                action: {
                  id: 'Ci::BuildPresenter-failed-12230',
                  path: '/root/ci-project/-/jobs/12230/retry',
                  icon: 'retry',
                  __typename: 'StatusAction',
                },
                __typename: 'DetailedStatus',
              },
              kind: 'BUILD',
              name: 'mr_job_two',
              retried: false,
              retryable: true,
              stage: {
                id: 'gid://gitlab/Ci::Stage/3472',
                name: 'test',
                __typename: 'CiStage',
              },
              userPermissions: {
                readBuild: true,
                updateBuild: true,
                __typename: 'JobPermissions',
              },
              __typename: 'CiJob',
            },
          ],
          __typename: 'CiJobConnection',
        },
      },
      __typename: 'Project',
    },
  },
};
