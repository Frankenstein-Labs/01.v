import { pick } from 'lodash-es';
import mockAiMetricsResponse from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.json';
import mockAiMetricsResponseColumn2 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_2.json';
import mockAiMetricsResponseColumn3 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_3.json';
import mockAiMetricsResponseColumn4 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_4.json';
import mockAiMetricsResponseColumn5 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_5.json';
import mockAiMetricsResponseColumn6 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_6.json';

export const mockTimePeriods = [
  {
    key: '5-months-ago',
    label: 'Oct',
    start: new Date('2023-10-01T00:00:00.000Z'),
    end: new Date('2023-10-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 10,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '8.9',
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 0,
    },
    issues_completed: {
      identifier: 'issues_completed',
      value: 999999,
    },
  },
  {
    key: '4-months-ago',
    label: 'Nov',
    start: new Date('2023-11-01T00:00:00.000Z'),
    end: new Date('2023-11-30T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 15,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '5.6',
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 100,
    },
  },
  {
    key: '3-months-ago',
    label: 'Dec',
    start: new Date('2023-12-01T00:00:00.000Z'),
    end: new Date('2023-12-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: null,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '0.0',
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 20,
    },
  },
  {
    key: '2-months-ago',
    label: 'Jan',
    start: new Date('2024-01-01T00:00:00.000Z'),
    end: new Date('2024-01-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: null,
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 90,
    },
  },
  {
    key: '1-months-ago',
    label: 'Feb',
    start: new Date('2024-02-01T00:00:00.000Z'),
    end: new Date('2024-02-29T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: '-',
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '7.5',
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 50,
    },
  },
  {
    key: 'this-month',
    label: 'Mar',
    start: new Date('2024-03-01T00:00:00.000Z'),
    end: new Date('2024-03-15T13:00:00.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '4.0',
    },
    code_suggestions_users_count: {
      identifier: 'code_suggestions_users_count',
      value: 88,
    },
  },
];

const aiTableMetricsFields = [
  'agentPlatformChatsCreatedSessionEventCount',
  'agentPlatformFlowsCreatedSessionEventCount',
  'requestReviewDuoCodeReviewOnMrByAuthorEventCount',
  'requestReviewDuoCodeReviewOnMrByNonAuthorEventCount',
  'postCommentDuoCodeReviewOnDiffEventCount',
  'reactThumbsUpOnDuoCodeReviewCommentEventCount',
  'reactThumbsDownOnDuoCodeReviewCommentEventCount',
  'contributorsCount',
  'acceptedCount',
  'shownCount',
  'acceptedLinesOfCode',
  'shownLinesOfCode',
  'codeContributorsCount',
  'duoChatContributorsCount',
  'rootCauseAnalysisUsersCount',
  'duoUsedCount',
];

const formatMockAiTableMetrics = (response) => {
  const { aiMetrics } = response.data.group;
  const {
    codeReview,
    codeSuggestions,
    agentPlatformChats: { createdSessionEventCount: agentPlatformChatsCreatedSessionEventCount },
    agentPlatformFlows: { createdSessionEventCount: agentPlatformFlowsCreatedSessionEventCount },
    ...restAiMetrics
  } = aiMetrics;

  return pick(
    {
      agentPlatformChatsCreatedSessionEventCount,
      agentPlatformFlowsCreatedSessionEventCount,
      ...codeReview,
      ...codeSuggestions,
      ...restAiMetrics,
    },
    aiTableMetricsFields,
  );
};

export const mockTableValues = [
  {
    deploymentFrequency: 10,
    leadTimeForChanges: 100000,
    timeToRestoreService: 100000,
    changeFailureRate: 0.2,
    cycleTime: 1,
    leadTime: 1,
    issues: 1,
    issuesCompleted: 5,
    deploys: 5,
    medianTimeToMerge: 0.1,
    criticalVulnerabilities: 40,
    highVulnerabilities: 40,
    pipelineCount: 387,
    pipelineSuccessCount: 149,
    pipelineFailedCount: 175,
    pipelineOtherCount: 25,
    pipelineDurationMedian: 150,
    ...formatMockAiTableMetrics(mockAiMetricsResponse),
  },
  {
    deploymentFrequency: 20,
    leadTimeForChanges: 200000,
    timeToRestoreService: 200000,
    changeFailureRate: 0.4,
    cycleTime: 2,
    leadTime: 2,
    issues: 2,
    issuesCompleted: 10,
    deploys: 10,
    medianTimeToMerge: 0.2,
    criticalVulnerabilities: 20,
    highVulnerabilities: 20,
    pipelineCount: 37,
    pipelineSuccessCount: 49,
    pipelineFailedCount: 15,
    pipelineOtherCount: 8,
    pipelineDurationMedian: 120,
    ...formatMockAiTableMetrics(mockAiMetricsResponseColumn2),
  },
  {
    deploymentFrequency: 40,
    leadTimeForChanges: 400000,
    timeToRestoreService: 400000,
    changeFailureRate: 0.6,
    cycleTime: 4,
    leadTime: 4,
    issues: 4,
    issuesCompleted: 20,
    deploys: 20,
    medianTimeToMerge: 0.3,
    criticalVulnerabilities: 10,
    highVulnerabilities: 10,
    pipelineCount: 27,
    pipelineSuccessCount: 10,
    pipelineFailedCount: 5,
    pipelineOtherCount: 1,
    pipelineDurationMedian: 165,
    ...formatMockAiTableMetrics(mockAiMetricsResponseColumn3),
  },
  {
    deploymentFrequency: 10,
    leadTimeForChanges: 100000,
    timeToRestoreService: 100000,
    changeFailureRate: 0.2,
    cycleTime: 1,
    leadTime: 1,
    issues: 1,
    issuesCompleted: 5,
    deploys: 5,
    medianTimeToMerge: 0.3,
    criticalVulnerabilities: 40,
    highVulnerabilities: 40,
    pipelineCount: 95,
    pipelineSuccessCount: 60,
    pipelineFailedCount: 10,
    pipelineOtherCount: 3,
    pipelineDurationMedian: 90,
    ...formatMockAiTableMetrics(mockAiMetricsResponseColumn4),
  },
  {
    deploymentFrequency: 20,
    leadTimeForChanges: 200000,
    timeToRestoreService: 200000,
    changeFailureRate: 0.4,
    cycleTime: 2,
    leadTime: 2,
    issues: 2,
    issuesCompleted: 10,
    deploys: 10,
    medianTimeToMerge: 0.2,
    criticalVulnerabilities: 20,
    highVulnerabilities: 20,
    pipelineCount: 75,
    pipelineSuccessCount: 18,
    pipelineFailedCount: 15,
    pipelineOtherCount: 2,
    pipelineDurationMedian: 250,
    ...formatMockAiTableMetrics(mockAiMetricsResponseColumn5),
  },
  {
    deploymentFrequency: 40,
    leadTimeForChanges: 400000,
    timeToRestoreService: 400000,
    changeFailureRate: 0.6,
    cycleTime: 4,
    leadTime: 4,
    issues: 4,
    issuesCompleted: 20,
    deploys: 20,
    medianTimeToMerge: 0.1,
    criticalVulnerabilities: 10,
    highVulnerabilities: 10,
    pipelineCount: 100,
    pipelineSuccessCount: 50,
    pipelineFailedCount: 25,
    pipelineOtherCount: 25,
    pipelineDurationMedian: 100,
    ...formatMockAiTableMetrics(mockAiMetricsResponseColumn6),
  },
];

const mockUniformTableRow = (value) => ({
  deploymentFrequency: value,
  changeFailureRate: value,
  leadTimeForChanges: value,
  timeToRestoreService: value,
  cycleTime: value,
  leadTime: value,
  issues: value,
  issuesCompleted: value,
  deploys: value,
  medianTimeToMerge: value,
  criticalVulnerabilities: value,
  highVulnerabilities: value,
  pipelineCount: value,
  pipelineSuccessCount: value,
  pipelineFailedCount: value,
  pipelineOtherCount: value,
  pipelineDurationMedian: value,
  ...Object.fromEntries(aiTableMetricsFields.map((field) => [field, value])),
});

export const mockTableBlankValues = [
  mockUniformTableRow('-'),
  mockUniformTableRow('-'),
  mockUniformTableRow('-'),
  mockUniformTableRow('-'),
  mockUniformTableRow('-'),
  mockUniformTableRow('-'),
];

export const mockTableZeroValues = [
  mockUniformTableRow(0),
  mockUniformTableRow(0),
  mockUniformTableRow(0),
  mockUniformTableRow(0),
  mockUniformTableRow(0),
  mockUniformTableRow(0),
];

export const mockTableMaxLimitValues = [
  mockUniformTableRow(999999),
  mockUniformTableRow(999999),
  mockUniformTableRow(999999),
  mockUniformTableRow(999999),
  mockUniformTableRow(999999),
  mockUniformTableRow(999999),
];

export const mockTableAndChartValues = [...mockTableValues, ...mockTableValues];

const mockAiMetricsResponses = [
  mockAiMetricsResponse,
  mockAiMetricsResponseColumn2,
  mockAiMetricsResponseColumn3,
  mockAiMetricsResponseColumn4,
  mockAiMetricsResponseColumn5,
  mockAiMetricsResponseColumn6,
];
export const mockAiTableAndChartValues = [...mockAiMetricsResponses, ...mockAiMetricsResponses];
