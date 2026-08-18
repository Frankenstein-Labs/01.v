export const mockDoraPerformersScoreResponseData = [
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'deployment_frequency',
    lowProjectsCount: 27,
    mediumProjectsCount: 24,
    highProjectsCount: 86,
    noDataProjectsCount: 1,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'lead_time_for_changes',
    lowProjectsCount: 25,
    mediumProjectsCount: 30,
    highProjectsCount: 75,
    noDataProjectsCount: 1,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'time_to_restore_service',
    lowProjectsCount: 80,
    mediumProjectsCount: 55,
    highProjectsCount: 15,
    noDataProjectsCount: 1,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'change_failure_rate',
    lowProjectsCount: 81,
    mediumProjectsCount: 70,
    highProjectsCount: 5,
    noDataProjectsCount: 1,
  },
];

export const mockEmptyDoraPerformersScoreResponseData = [
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'deployment_frequency',
    lowProjectsCount: null,
    mediumProjectsCount: null,
    highProjectsCount: null,
    noDataProjectsCount: 70,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'lead_time_for_changes',
    lowProjectsCount: null,
    mediumProjectsCount: null,
    highProjectsCount: null,
    noDataProjectsCount: 70,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'time_to_restore_service',
    lowProjectsCount: null,
    mediumProjectsCount: null,
    highProjectsCount: null,
    noDataProjectsCount: 70,
  },
  {
    __typename: 'DoraPerformanceScoreCount',
    metricName: 'change_failure_rate',
    lowProjectsCount: null,
    mediumProjectsCount: null,
    highProjectsCount: null,
    noDataProjectsCount: 70,
  },
];

export const mockDoraPerformersScoreChartData = [
  {
    name: 'High',
    data: [86, 75, 15, 5],
  },
  {
    name: 'Medium',
    data: [24, 30, 55, 70],
  },
  {
    name: 'Low',
    data: [27, 25, 80, 81],
  },
  {
    name: 'Not included',
    data: [1, 1, 1, 1],
  },
];
