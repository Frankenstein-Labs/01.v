/* eslint-disable @gitlab/no-hardcoded-urls -- REST API routes using Api.buildUrl is acceptable */
import Api, { DEFAULT_PER_PAGE } from '~/api';
import axios from '~/lib/utils/axios_utils';
import { contentTypeMultipartFormData } from '~/lib/utils/headers';
import { VULNERABILITY_RESOLUTION_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';

export default {
  ...Api,
  geoSitePath: '/api/:version/geo_sites/:id',
  geoSitesPath: '/api/:version/geo_sites',
  geoSitesStatusPath: '/api/:version/geo_sites/status',
  ldapGroupsPath: '/api/:version/ldap/:provider/groups.json',
  subscriptionPath: '/api/:version/namespaces/:id/gitlab_subscription',
  childEpicPath: '/api/:version/groups/:id/epics',
  codeReviewAnalyticsPath: '/api/:version/analytics/code_review',
  groupActivityIssuesPath: '/api/:version/analytics/group_activity/issues_count',
  groupActivityMergeRequestsPath: '/api/:version/analytics/group_activity/merge_requests_count',
  groupActivityNewMembersPath: '/api/:version/analytics/group_activity/new_members_count',
  countriesPath: '/-/countries',
  countryStatesPath: '/-/country_states',
  paymentFormPath: '/-/subscriptions/payment_form',
  filePath: '/api/:version/projects/:id/repository/files/:file_path',
  validatePaymentMethodPath: '/-/subscriptions/validate_payment_method',
  vulnerabilityPath: '/api/:version/vulnerabilities/:id',
  vulnerabilityActionPath: '/api/:version/vulnerabilities/:id/:action',
  vulnerabilityIssueLinksPath: '/api/:version/vulnerabilities/:id/issue_links',
  duoWorkflowsPath: '/api/:version/ai/duo_workflows/workflows',
  duoWorkflowsWsPath: '/api/:version/ai/duo_workflows/ws',
  policyStoreTriggersPath: '/api/:version/security/policy_store/triggers',
  policyStoreRulesPath: '/api/:version/security/policy_store/rules',
  policyStoreActionsPath: '/api/:version/security/policy_store/actions',
  policyStorePoliciesPath: '/api/:version/organizations/:id/security/policy_store',
  policyStorePolicyPath: '/api/:version/organizations/:id/security/policy_store/:policy_id',
  descendantGroupsPath: '/api/:version/groups/:group_id/descendant_groups',
  projectDeploymentFrequencyAnalyticsPath:
    '/api/:version/projects/:id/analytics/deployment_frequency',
  projectGroupsPath: '/api/:version/projects/:id/groups.json',
  issueMetricImagesPath: '/api/:version/projects/:id/issues/:issue_iid/metric_images',
  issueMetricSingleImagePath:
    '/api/:version/projects/:id/issues/:issue_iid/metric_images/:image_id',
  environmentApprovalPath: '/api/:version/projects/:id/deployments/:deployment_id/approval',
  protectedEnvironmentsPath: '/api/:version/:entity_type/:id/protected_environments/',
  mrStatusCheckRetryPath:
    '/api/:version/projects/:id/merge_requests/:merge_request_iid/status_checks/:external_status_check_id/retry',
  compliancePolicySettings: '/api/:version/admin/security/compliance_policy_settings',
  protectedEnvironmentPath: '/api/:version/:entity_type/:id/protected_environments/:name',
  aiCompletionsPath: '/api/:version/ai/experimentation/openai/completions',
  aiEmbeddingsPath: '/api/:version/ai/experimentation/openai/embeddings',
  aiChatPath: '/api/:version/ai/experimentation/openai/chat/completions',
  tanukiBotAskPath: '/-/llm/tanuki_bot/ask',
  userPreferencesPath: '/api/:version/user/preferences',

  updateUserPreferences(advancedEditorEnabled) {
    const url = Api.buildUrl(this.userPreferencesPath);

    return axios.put(url, { policy_advanced_editor: advancedEditorEnabled });
  },

  userSubscription(namespaceId) {
    const url = Api.buildUrl(this.subscriptionPath).replace(':id', encodeURIComponent(namespaceId));

    return axios.get(url);
  },

  ldapGroups(query, provider) {
    const url = Api.buildUrl(this.ldapGroupsPath).replace(':provider', provider);
    return axios.get(url, {
      params: {
        search: query,
        per_page: DEFAULT_PER_PAGE,
        active: true,
      },
    });
  },

  createChildEpic({ confidential, groupId, parentEpicId, title }) {
    const url = Api.buildUrl(this.childEpicPath).replace(':id', encodeURIComponent(groupId));

    return axios.post(url, {
      parent_id: parentEpicId,
      confidential,
      title,
    });
  },

  descendantGroups({ groupId, search }) {
    const url = Api.buildUrl(this.descendantGroupsPath).replace(':group_id', groupId);

    return axios.get(url, {
      params: {
        search,
      },
    });
  },

  codeReviewAnalytics(params = {}) {
    const url = Api.buildUrl(this.codeReviewAnalyticsPath);
    return axios.get(url, { params });
  },

  groupActivityMergeRequestsCount(groupPath) {
    const url = Api.buildUrl(this.groupActivityMergeRequestsPath);
    return axios.get(url, { params: { group_path: groupPath } });
  },

  groupActivityIssuesCount(groupPath) {
    const url = Api.buildUrl(this.groupActivityIssuesPath);
    return axios.get(url, { params: { group_path: groupPath } });
  },

  groupActivityNewMembersCount(groupPath) {
    const url = Api.buildUrl(this.groupActivityNewMembersPath);
    return axios.get(url, { params: { group_path: groupPath } });
  },

  fetchCountries() {
    const url = Api.buildUrl(this.countriesPath);
    return axios.get(url);
  },

  fetchStates(country) {
    const url = Api.buildUrl(this.countryStatesPath);
    return axios.get(url, { params: { country } });
  },

  fetchPaymentFormParams(id) {
    const url = Api.buildUrl(this.paymentFormPath);
    return axios.get(url, { params: { id } });
  },

  getFile(id, filePath, params = {}) {
    const url = Api.buildUrl(this.filePath)
      .replace(':id', encodeURIComponent(id))
      .replace(':file_path', encodeURIComponent(filePath));

    return axios.get(url, { params });
  },

  validatePaymentMethod(id, gitlabUserId) {
    const url = Api.buildUrl(this.validatePaymentMethodPath);
    return axios.post(url, { id, gitlab_user_id: gitlabUserId });
  },

  changeVulnerabilityState(id, state) {
    const url = Api.buildUrl(this.vulnerabilityActionPath)
      .replace(':id', id)
      .replace(':action', state);

    return axios.post(url);
  },

  triggerVulnerabilityResolution(vulnerabilityId, projectId, aiCatalogItemConsumerId) {
    const url = Api.buildUrl(this.duoWorkflowsPath);

    return axios.post(url, {
      project_id: projectId,
      goal: vulnerabilityId.toString(),
      ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
      start_workflow: true,
      workflow_definition: 'resolve_sast_vulnerability/v1',
      agent_privileges: VULNERABILITY_RESOLUTION_AGENT_PRIVILEGES,
      environment: 'web',
    });
  },

  triggerFalsePositiveDetection(vulnerabilityId, projectId, aiCatalogItemConsumerId) {
    const url = Api.buildUrl(this.duoWorkflowsPath);

    return axios.post(url, {
      project_id: projectId,
      goal: vulnerabilityId.toString(),
      ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
      start_workflow: true,
      workflow_definition: 'sast_fp_detection/v1',
      // needed to present this when calling workflow, reserved for future use
      agent_privileges: [1, 2, 3, 4, 5],
      environment: 'web',
    });
  },

  triggerSecretDetectionFalsePositiveDetection(
    vulnerabilityId,
    projectId,
    aiCatalogItemConsumerId,
  ) {
    const url = Api.buildUrl(this.duoWorkflowsPath);

    return axios.post(url, {
      project_id: projectId,
      goal: vulnerabilityId.toString(),
      ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
      start_workflow: true,
      workflow_definition: 'secrets_fp_detection/v1',
      agent_privileges: [1, 2, 3, 4, 5],
      environment: 'web',
    });
  },

  getGeoSites() {
    const url = Api.buildUrl(this.geoSitesPath);
    return axios.get(url);
  },

  getGeoSitesStatus() {
    const url = Api.buildUrl(this.geoSitesStatusPath);
    return axios.get(url);
  },

  getPolicyTriggers() {
    const url = Api.buildUrl(this.policyStoreTriggersPath);
    return axios.get(url);
  },

  getPolicyRules() {
    const url = Api.buildUrl(this.policyStoreRulesPath);
    return axios.get(url);
  },

  getPolicyActions() {
    const url = Api.buildUrl(this.policyStoreActionsPath);
    return axios.get(url);
  },

  getPolicyStorePolicies(organizationId) {
    const url = Api.buildUrl(this.policyStorePoliciesPath).replace(
      ':id',
      encodeURIComponent(organizationId),
    );
    return axios.get(url);
  },

  buildPolicyStorePolicyUrl(organizationId, policyId) {
    return Api.buildUrl(this.policyStorePolicyPath)
      .replace(':id', encodeURIComponent(organizationId))
      .replace(':policy_id', encodeURIComponent(policyId));
  },

  createPolicyStorePolicy(organizationId, params) {
    const url = Api.buildUrl(this.policyStorePoliciesPath).replace(
      ':id',
      encodeURIComponent(organizationId),
    );
    return axios.post(url, params);
  },

  updatePolicyStorePolicy(organizationId, policyId, params) {
    return axios.patch(this.buildPolicyStorePolicyUrl(organizationId, policyId), params);
  },

  getPolicyStorePolicy(organizationId, policyId) {
    return axios.get(this.buildPolicyStorePolicyUrl(organizationId, policyId));
  },

  deletePolicyStorePolicy(organizationId, policyId) {
    return axios.delete(this.buildPolicyStorePolicyUrl(organizationId, policyId));
  },

  createGeoSite(site) {
    const url = Api.buildUrl(this.geoSitesPath);
    return axios.post(url, site);
  },

  updateGeoSite(site) {
    const url = Api.buildUrl(this.geoSitesPath);
    return axios.put(`${url}/${site.id}`, site);
  },

  removeGeoSite(id) {
    const url = Api.buildUrl(this.geoSitePath).replace(':id', encodeURIComponent(id));
    return axios.delete(url);
  },

  deploymentFrequencies(projectId, params = {}) {
    const url = Api.buildUrl(this.projectDeploymentFrequencyAnalyticsPath).replace(
      ':id',
      encodeURIComponent(projectId),
    );

    return axios.get(url, { params });
  },

  fetchIssueMetricImages({ issueIid, id }) {
    const metricImagesUrl = Api.buildUrl(this.issueMetricImagesPath)
      .replace(':id', encodeURIComponent(id))
      .replace(':issue_iid', encodeURIComponent(issueIid));

    return axios.get(metricImagesUrl);
  },

  uploadIssueMetricImage({ issueIid, id, file, url = null, urlText = null }) {
    const options = { headers: { ...contentTypeMultipartFormData } };
    const metricImagesUrl = Api.buildUrl(this.issueMetricImagesPath)
      .replace(':id', encodeURIComponent(id))
      .replace(':issue_iid', encodeURIComponent(issueIid));

    // Construct multipart form data
    const formData = new FormData();
    formData.append('file', file);
    if (url) {
      formData.append('url', url);
    }
    if (urlText) {
      formData.append('url_text', urlText);
    }

    return axios.post(metricImagesUrl, formData, options);
  },

  updateIssueMetricImage({ issueIid, id, imageId, url = null, urlText = null }) {
    const metricImagesUrl = Api.buildUrl(this.issueMetricSingleImagePath)
      .replace(':id', encodeURIComponent(id))
      .replace(':issue_iid', encodeURIComponent(issueIid))
      .replace(':image_id', encodeURIComponent(imageId));

    // Construct multipart form data
    const formData = new FormData();
    if (url != null) {
      formData.append('url', url);
    }
    if (urlText != null) {
      formData.append('url_text', urlText);
    }

    return axios.put(metricImagesUrl, formData);
  },

  deleteMetricImage({ issueIid, id, imageId }) {
    const individualMetricImageUrl = Api.buildUrl(this.issueMetricSingleImagePath)
      .replace(':id', encodeURIComponent(id))
      .replace(':issue_iid', encodeURIComponent(issueIid))
      .replace(':image_id', encodeURIComponent(imageId));

    return axios.delete(individualMetricImageUrl);
  },

  projectGroups(id, options) {
    const url = Api.buildUrl(this.projectGroupsPath).replace(':id', encodeURIComponent(id));

    return axios
      .get(url, {
        params: {
          ...options,
        },
      })
      .then(({ data }) => {
        return data;
      });
  },

  deploymentApproval({ id, deploymentId, representedAs, approve, comment }) {
    const url = Api.buildUrl(this.environmentApprovalPath)
      .replace(':id', encodeURIComponent(id))
      .replace(':deployment_id', encodeURIComponent(deploymentId));

    return axios.post(url, {
      status: approve ? 'approved' : 'rejected',
      represented_as: representedAs,
      comment,
    });
  },

  approveDeployment({ id, deploymentId, representedAs, comment }) {
    return this.deploymentApproval({ id, deploymentId, representedAs, approve: true, comment });
  },
  rejectDeployment({ id, deploymentId, representedAs, comment }) {
    return this.deploymentApproval({ id, deploymentId, approve: false, representedAs, comment });
  },

  updateCompliancePolicySettings(settings) {
    const url = Api.buildUrl(this.compliancePolicySettings);
    return axios.put(url, settings);
  },

  protectedEnvironments(id, entityType, params = {}) {
    const url = Api.buildUrl(this.protectedEnvironmentsPath)
      .replace(':entity_type', encodeURIComponent(entityType))
      .replace(':id', encodeURIComponent(id));
    return axios.get(url, { params });
  },

  createProtectedEnvironment(id, entityType, protectedEnvironment) {
    const url = Api.buildUrl(this.protectedEnvironmentsPath)
      .replace(':entity_type', encodeURIComponent(entityType))
      .replace(':id', encodeURIComponent(id));
    return axios.post(url, protectedEnvironment);
  },

  updateProtectedEnvironment(id, entityType, protectedEnvironment) {
    const url = Api.buildUrl(this.protectedEnvironmentPath)
      .replace(':entity_type', encodeURIComponent(entityType))
      .replace(':id', encodeURIComponent(id))
      .replace(':name', encodeURIComponent(protectedEnvironment.name));

    return axios.put(url, protectedEnvironment);
  },

  deleteProtectedEnvironment(id, entityType, { name }) {
    const url = Api.buildUrl(this.protectedEnvironmentPath)
      .replace(':entity_type', encodeURIComponent(entityType))
      .replace(':id', encodeURIComponent(id))
      .replace(':name', encodeURIComponent(name));

    return axios.delete(url);
  },

  requestAICompletions({ model, prompt, ...rest }) {
    const url = Api.buildUrl(this.aiCompletionsPath);
    return axios.post(url, { model, prompt, rest });
  },

  requestAIEmbeddings({ model, input, ...rest }) {
    const url = Api.buildUrl(this.aiEmbeddingsPath);
    return axios.post(url, { model, input, rest });
  },

  requestAIChat({ model, messages, ...rest }) {
    const url = Api.buildUrl(this.aiChatPath);
    return axios.post(url, { model, messages, rest });
  },

  requestTanukiBotResponse(q) {
    const url = Api.buildUrl(this.tanukiBotAskPath);
    return axios.post(url, { q });
  },
};
