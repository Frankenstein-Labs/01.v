export const mockDoraMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { deploymentFrequency, changeFailureRate, leadTimeForChanges, timeToRestoreService }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-dora-metrics-request',
            dora: {
              metrics: [
                {
                  date: null,
                  deployment_frequency: deploymentFrequency,
                  change_failure_rate: changeFailureRate,
                  lead_time_for_changes: leadTimeForChanges,
                  time_to_restore_service: timeToRestoreService,
                  __typename: 'DoraMetric',
                },
              ],
              __typename: 'Dora',
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockFlowMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { cycleTime, leadTime, issues, issuesCompleted, deploys, medianTimeToMerge }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-flow-metrics-request',
            flowMetrics: {
              cycle_time: {
                unit: 'days',
                value: cycleTime,
                identifier: 'cycle_time',
                links: [],
                title: 'Cycle time',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              lead_time: {
                unit: 'days',
                value: leadTime,
                identifier: 'lead_time',
                links: [
                  {
                    label: 'Dashboard',
                    name: 'Lead time',
                    docsLink: null,
                    url: '/groups/test-graphql-dora/-/issues_analytics',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                  {
                    label: 'Learn more',
                    name: 'Lead time',
                    docsLink: true,
                    url: '/help/user/analytics/index#definitions',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                ],
                title: 'Lead time',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              issues: {
                unit: 'count',
                value: issues,
                identifier: 'issues',
                links: [],
                title: 'Issues created',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              issues_completed: {
                unit: 'count',
                value: issuesCompleted,
                identifier: 'issues_completed',
                links: [],
                title: 'Issues completed',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              deploys: {
                unit: 'count',
                value: deploys,
                identifier: 'deploys',
                links: [],
                title: 'Deploys',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              median_time_to_merge: {
                unit: 'days',
                value: medianTimeToMerge,
                identifier: 'median_time_to_merge',
                links: [
                  {
                    label: 'Dashboard',
                    name: 'Median time to merge',
                    docsLink: null,
                    url: '/groups/test-graphql-dora/-/issues_analytics',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                  {
                    label: 'Learn more',
                    name: 'Median time to merge',
                    docsLink: true,
                    url: '/help/user/analytics/index#definitions',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                ],
                title: 'Median time to merge',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              __typename: 'GroupValueStreamAnalyticsFlowMetrics',
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockVulnerabilityMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { criticalVulnerabilities, highVulnerabilities }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-vulnerability-request',
            vulnerabilitiesCountByDay: {
              nodes: [
                {
                  date: null,
                  critical: criticalVulnerabilities,
                  high: highVulnerabilities,
                },
              ],
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockAiMetricsResponse = (fixtures = []) =>
  fixtures.reduce((acc, fixture) => acc.mockResolvedValueOnce(fixture), jest.fn());

export const mockAggregatedPipelineMetricsResponse = (values = []) =>
  values.reduce(
    (
      acc,
      {
        pipelineCount,
        pipelineSuccessCount,
        pipelineFailedCount,
        pipelineOtherCount,
        pipelineDurationMedian,
      },
    ) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-pipeline-metrics',
            pipelineAnalytics: {
              aggregate: {
                pipelineCount,
                pipelineSuccessCount,
                pipelineFailedCount,
                pipelineOtherCount,
                durationStatistics: {
                  pipelineDurationMedian,
                  __typename: 'CiDurationStatistics',
                },
                __typename: 'PipelineAnalyticsPeriod',
              },
              __typename: 'PipelineAnalytics',
            },
          },
        },
      }),
    jest.fn(),
  );
