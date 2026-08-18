import { parseBoolean } from '~/lib/utils/common_utils';
import { DASHBOARD_TYPE_PIPELINE } from 'ee/security_dashboard/constants';
import findingsQuery from 'ee/security_dashboard/graphql/queries/pipeline_findings.query.graphql';

export const getPipelineReportOptions = (data) => {
  const {
    projectFullPath,
    emptyStateSvgPath,
    canAdminVulnerability,
    pipelineId,
    pipelineIid,
    pipelineJobsPath,
    sourceBranch,
    canViewFalsePositive,
    hasJiraVulnerabilitiesIntegrationEnabled,
    hasVulnerabilities,
    noVulnerabilitiesSvgPath,
    customizeJiraIssueEnabled,
  } = data;

  return {
    projectFullPath,
    emptyStateSvgPath,
    dashboardType: DASHBOARD_TYPE_PIPELINE,
    // fullPath is needed even though projectFullPath is already provided because
    // vulnerability_list_graphql.vue expects the property name to be 'fullPath'
    fullPath: projectFullPath,
    canAdminVulnerability: parseBoolean(canAdminVulnerability),
    pipeline: {
      id: Number(pipelineId),
      iid: Number(pipelineIid),
      jobsPath: pipelineJobsPath,
      sourceBranch,
    },
    canViewFalsePositive: parseBoolean(canViewFalsePositive),
    vulnerabilitiesQuery: findingsQuery,
    hasJiraVulnerabilitiesIntegrationEnabled: parseBoolean(
      hasJiraVulnerabilitiesIntegrationEnabled,
    ),
    hasVulnerabilities: parseBoolean(hasVulnerabilities),
    noVulnerabilitiesSvgPath,
    customizeJiraIssueEnabled: parseBoolean(customizeJiraIssueEnabled),
  };
};
