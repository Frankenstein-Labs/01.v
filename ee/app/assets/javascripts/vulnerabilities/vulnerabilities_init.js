import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/security_dashboard/graphql/provider';
import Vulnerability from 'ee/vulnerabilities/components/vulnerability.vue';
import { fromHaml } from 'ee/vulnerabilities/components/vulnerability_details_enrichment/adapters/from_haml';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import createRouter from 'ee/security_dashboard/router';
import { DISMISSAL_REASON_DESCRIPTIONS } from 'ee/vulnerabilities/constants';

const initVulnerabilityDetailsEnrichment = (el) => {
  const VulnerabilityDetailsEnrichment = () =>
    import('ee/vulnerabilities/components/vulnerability_details_enrichment/index.vue');

  // Reshape the HAML payload into the GraphQL query response shape so the page
  // is already built against the eventual GraphQL contract (see the adapter).
  // `viewLayerPaths` are the help-doc paths, route URLs, and REST endpoints the
  // reused Related section components (related_issues.vue, related_jira_issues.vue,
  // create_jira_issue.vue) and the header actions (vulnerability_actions.vue,
  // `createMrUrl`) read via inject. They are view-layer values GraphQL is
  // unlikely to expose, so they stay sourced from the payload rather than the
  // reshaped `vulnerability`, and are read off the same payload the adapter already
  // parsed so we don't parse `el.dataset.vulnerability` a second time (#601897).
  const { vulnerability, viewLayerPaths } = fromHaml(el.dataset);
  const {
    projectFullPath,
    defaultBranch,
    commitPathTemplate,
    canViewFalsePositive,
    duoAgentPlatformAvailable,
    duoSecretDetectionFpEnabled,
    duoSastFalsePositiveDetectionEnabled,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'VulnerabilityDetailsEnrichmentRoot',
    apolloProvider,
    provide: {
      // Declared on the FE rather than injected from HAML; mirrors the backend
      // enum descriptions and reuses the shared `.po` catalog.
      dismissalDescriptions: DISMISSAL_REASON_DESCRIPTIONS,
      projectFullPath,
      defaultBranch,
      // Read by the Evidence panel's `commit` generic-report node to build its
      // commit link (generic_report/types/report_type_commit.vue).
      commitPathTemplate,
      // View-layer paths legacy bridge (#601897); carries the Related section
      // endpoints and the header actions' `createMrUrl`. `vulnerabilityId` and
      // `canModifyRelatedIssues` are intentionally absent: index.vue owns the
      // normalized numeric id (provided once for the inject-based subtrees) and
      // the `userPermissions.adminVulnerabilityIssueLink` permission, and threads
      // both down as props.
      ...viewLayerPaths,
      canViewFalsePositive: parseBoolean(canViewFalsePositive),
      customizeJiraIssueEnabled: parseBoolean(el.dataset.customizeJiraIssueEnabled),
      duoAgentPlatformAvailable: parseBoolean(duoAgentPlatformAvailable),
      duoSecretDetectionFpEnabled: parseBoolean(duoSecretDetectionFpEnabled),
      duoSastFalsePositiveDetectionEnabled: parseBoolean(duoSastFalsePositiveDetectionEnabled),
    },
    component: VulnerabilityDetailsEnrichment,
    props: { vulnerability },
  });
};

const initVulnerabilityDetails = (el) => {
  const {
    canViewFalsePositive,
    projectFullPath,
    defaultBranch,
    customizeJiraIssueEnabled,
    duoAgentPlatformAvailable,
    duoSecretDetectionFpEnabled,
    duoSastFalsePositiveDetectionEnabled,
  } = el.dataset;

  const vulnerabilityJson = JSON.parse(el.dataset.vulnerability);
  const dismissalDescriptions = vulnerabilityJson.dismissal_descriptions;

  const vulnerability = convertObjectPropsToCamelCase(JSON.parse(el.dataset.vulnerability), {
    deep: true,
  });

  const router = createRouter();

  return initVueApp({
    el,
    name: 'VulnerabilityRoot',
    router,
    apolloProvider,
    provide: {
      newIssueUrl: vulnerability.newIssueUrl,
      commitPathTemplate: el.dataset.commitPathTemplate,
      vulnerabilityId: vulnerability.id,
      createJiraIssueUrl: vulnerability.createJiraIssueUrl,
      relatedJiraIssuesPath: vulnerability.relatedJiraIssuesPath,
      relatedJiraIssuesHelpPath: vulnerability.relatedJiraIssuesHelpPath,
      jiraIntegrationSettingsPath: vulnerability.jiraIntegrationSettingsPath,
      canViewFalsePositive: parseBoolean(canViewFalsePositive),
      customizeJiraIssueEnabled: parseBoolean(customizeJiraIssueEnabled),
      duoAgentPlatformAvailable: parseBoolean(duoAgentPlatformAvailable),
      duoSecretDetectionFpEnabled: parseBoolean(duoSecretDetectionFpEnabled),
      duoSastFalsePositiveDetectionEnabled: parseBoolean(duoSastFalsePositiveDetectionEnabled),
      projectFullPath,
      defaultBranch,
      dismissalDescriptions,
    },
    component: Vulnerability,
    props: { initialVulnerability: vulnerability },
  });
};

export default (el) => {
  if (!el) {
    return null;
  }

  return gon?.features?.vulnerabilityDetailsEnrichment
    ? initVulnerabilityDetailsEnrichment(el)
    : initVulnerabilityDetails(el);
};
