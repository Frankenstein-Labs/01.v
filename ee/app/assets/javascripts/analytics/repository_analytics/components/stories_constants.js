export const projectsTestCoverageResponse = {
  data: {
    group: {
      id: 101,
      projects: {
        nodes: [
          {
            fullPath: 'fake-group/tui',
            id: 'gid://fake-domain/Project/1234',
            name: 'tui',
            repository: {
              rootRef: 'main',
              __typename: 'Repository',
            },
            codeCoverageSummary: {
              averageCoverage: 45.4,
              coverageCount: 2,
              lastUpdatedOn: '2020-09-24',
              __typename: 'CodeCoverageSummary',
            },
            __typename: 'Project',
          },
          {
            fullPath: 'fake-group/cli',
            id: 'gid://fake-domain/Project/5678',
            name: 'cli',
            repository: {
              rootRef: 'master',
              __typename: 'Repository',
            },
            codeCoverageSummary: {
              averageCoverage: 64.3,
              coverageCount: 1,
              lastUpdatedOn: '2020-08-19',
              __typename: 'CodeCoverageSummary',
            },
            __typename: 'Project',
          },
        ],
      },
    },
  },
};

export const projectsTestCoverageNoDataResponse = {
  data: {
    group: {
      id: 101,
      projects: { nodes: [] },
    },
  },
};

export const groupTestCoverageResponse = {
  data: {
    group: {
      id: 10,
      codeCoverageActivities: {
        nodes: [
          {
            projectCount: 4,
            averageCoverage: 59.49,
            coverageCount: 6,
            date: '2020-05-25',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 3,
            averageCoverage: 55.65,
            coverageCount: 5,
            date: '2020-05-26',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 5,
            averageCoverage: 63.48,
            coverageCount: 10,
            date: '2020-05-27',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 6,
            averageCoverage: 75.49,
            coverageCount: 8,
            date: '2020-05-28',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 6,
            averageCoverage: 55.45,
            coverageCount: 8,
            date: '2020-05-29',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 1,
            averageCoverage: 35.63,
            coverageCount: 5,
            date: '2020-05-30',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 3,
            averageCoverage: 61.45,
            coverageCount: 5,
            date: '2020-05-31',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 3,
            averageCoverage: 61.45,
            coverageCount: 5,
            date: '2020-06-01',
            __typename: 'CodeCoverageActivity',
          },
          {
            projectCount: 4,
            averageCoverage: 79.46,
            coverageCount: 6,
            date: '2020-06-02',
            __typename: 'CodeCoverageActivity',
          },
        ],
      },
    },
  },
};

export const groupTestCoverageNoDataResponse = {
  data: { group: { id: 10, codeCoverageActivities: { nodes: [] } } },
};
