<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import { refreshCurrentPageWithAlerts, visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import { AVAILABILITY_OPTIONS, ACCESS_LEVEL_EVERYONE_INTEGER } from '../constants';
import AiCommonSettings from '../components/ai_common_settings.vue';
import DuoToolSettingsForm from '../components/duo_tool_settings_form.vue';
import DuoWorkflowPromptInjectionForm from '../components/duo_workflow_prompt_injection_form.vue';
import AiUsageDataCollectionForm from '../components/ai_usage_data_collection_form.vue';
import AiCatalogRestrictedToGroupHierarchyForm from '../components/ai_catalog_restricted_to_group_hierarchy_form.vue';
import DuoAuditEventStorageForm from '../components/duo_audit_event_storage_form.vue';
import NetworkAccessSettings from '../components/network_access_settings.vue';

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
    DuoToolSettingsForm,
    DuoWorkflowPromptInjectionForm,
    AiUsageDataCollectionForm,
    AiCatalogRestrictedToGroupHierarchyForm,
    DuoAuditEventStorageForm,
    NetworkAccessSettings,
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: [
    'duoAvailability',
    'onGeneralSettingsPage',
    'duoWorkflowAvailable',
    'duoWorkflowMcpAvailable',
    'duoWorkflowMcpEnabled',
    'aiUsageDataCollectionAvailable',
    'aiUsageDataCollectionEnabled',
    'aiCatalogRestrictedToGroupHierarchy',
    'aiCatalogRestrictedToGroupHierarchyAvailable',
    'aiAuditEventsStorageEnabled',
    'promptInjectionProtectionLevel',
    'promptInjectionProtectionAvailable',
    'initialMinimumAccessLevelExecuteAsync',
    'initialMinimumAccessLevelExecuteSync',
    'glFeatures',
    'groupFullPath',
    'includeRecommendedAllowedDomains',
    'allowAllUnixSockets',
    'allowProjectExtension',
    'initialCodeReviewFlowConsentGiven',
  ],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    updateId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      codeReviewFlowConsentGiven: this.initialCodeReviewFlowConsentGiven,
      availability: this.duoAvailability,
      duoWorkflowMcp: this.duoWorkflowMcpEnabled,
      aiUsageDataCollection: this.aiUsageDataCollectionEnabled,
      aiCatalogRestrictedToGroupHierarchyValue: this.aiCatalogRestrictedToGroupHierarchy,
      aiAuditEventsStorage: this.aiAuditEventsStorageEnabled,
      promptInjectionProtection: this.promptInjectionProtectionLevel,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
      includeRecommendedAllowedDomainsInput: this.includeRecommendedAllowedDomains,
      allowAllUnixSocketsInput: this.allowAllUnixSockets,
      allowProjectExtensionInput: this.allowProjectExtension,
    };
  },
  computed: {
    disableConfigCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    hasFormChanged() {
      return (
        this.duoWorkflowMcpEnabled !== this.duoWorkflowMcp ||
        this.aiUsageDataCollectionEnabled !== this.aiUsageDataCollection ||
        this.aiCatalogRestrictedToGroupHierarchy !==
          this.aiCatalogRestrictedToGroupHierarchyValue ||
        this.aiAuditEventsStorageEnabled !== this.aiAuditEventsStorage ||
        this.promptInjectionProtectionLevel !== this.promptInjectionProtection ||
        this.includeRecommendedAllowedDomainsInput !== this.includeRecommendedAllowedDomains ||
        this.allowAllUnixSocketsInput !== this.allowAllUnixSockets ||
        this.allowProjectExtensionInput !== this.allowProjectExtension ||
        this.codeReviewFlowConsentGiven !== this.initialCodeReviewFlowConsentGiven
      );
    },
    showWorkflowSettingsForm() {
      return this.duoWorkflowAvailable || this.promptInjectionProtectionAvailable;
    },
    hasMinimumAccessLevelExecuteAsyncChanged() {
      return this.minimumAccessLevelExecuteAsync !== this.initialMinimumAccessLevelExecuteAsync;
    },
    hasMinimumAccessLevelExecuteSyncChanged() {
      return this.minimumAccessLevelExecuteSync !== this.initialMinimumAccessLevelExecuteSync;
    },
    hasIncludeRecommendedAllowedChanged() {
      return this.includeRecommendedAllowedDomainsInput !== this.includeRecommendedAllowedDomains;
    },
    hasAllowAllUnixSocketsChanged() {
      return this.allowAllUnixSocketsInput !== this.allowAllUnixSockets;
    },
    hasAllowProjectExtensionChanged() {
      return this.allowProjectExtensionInput !== this.allowProjectExtension;
    },
  },
  methods: {
    onCodeReviewFlowConsentGiven() {
      this.codeReviewFlowConsentGiven = true;
    },
    async updateSettings({
      duoAvailability,
      duoRemoteFlowsAvailability,
      experimentFeaturesEnabled,
      duoCoreFeaturesEnabled,
      promptCacheEnabled,
      duoFoundationalFlowsAvailability,
      duoCustomAgentsAvailability,
      duoCustomFlowsAvailability,
      duoExternalAgentsAvailability,
      foundationalAgentsEnabled,
      foundationalAgentsStatuses,
      selectedFoundationalFlowIds,
      duoAgentPlatformEnabled,
      toolApprovalForSessionAvailability,
      namespaceAccessRules,
      minimumAccessLevelExecuteSync,
      minimumAccessLevelExecuteAsync,
      duoTemplateProject,
    }) {
      try {
        const transformedFoundationalAgentsStatuses = foundationalAgentsStatuses?.filter(
          (agent) => agent.enabled !== null,
        );

        this.minimumAccessLevelExecuteSync = minimumAccessLevelExecuteSync;
        this.minimumAccessLevelExecuteAsync = minimumAccessLevelExecuteAsync;

        const input = {
          duo_availability: duoAvailability,
          experiment_features_enabled: experimentFeaturesEnabled,
          model_prompt_cache_enabled: promptCacheEnabled,
          duo_remote_flows_availability: duoRemoteFlowsAvailability,
          duo_foundational_flows_availability: duoFoundationalFlowsAvailability,
          duo_custom_agents_availability: duoCustomAgentsAvailability,
          duo_custom_flows_availability: duoCustomFlowsAvailability,
          duo_external_agents_availability: duoExternalAgentsAvailability,
          enabled_foundational_flows: selectedFoundationalFlowIds,
          duo_template_project_id: duoTemplateProject?.id ?? null,
          ...(foundationalAgentsStatuses && {
            foundational_agents_statuses: transformedFoundationalAgentsStatuses,
          }),
          tool_approval_for_session_availability: toolApprovalForSessionAvailability,
          ai_settings_attributes: {
            duo_agent_platform_enabled: duoAgentPlatformEnabled,
            ...(this.duoWorkflowAvailable && {
              duo_workflow_mcp_enabled: this.duoWorkflowMcp,
            }),
            ai_usage_data_collection_enabled: this.aiUsageDataCollection,
            ai_catalog_restricted_to_group_hierarchy: this.aiCatalogRestrictedToGroupHierarchyValue,
            ...(this.promptInjectionProtectionAvailable && {
              prompt_injection_protection_level: this.promptInjectionProtection,
            }),
            foundational_agents_default_enabled: foundationalAgentsEnabled,
            ...(this.hasIncludeRecommendedAllowedChanged && {
              include_recommended_allowed: this.includeRecommendedAllowedDomainsInput,
            }),
            ...(this.hasAllowAllUnixSocketsChanged && {
              allow_all_unix_sockets: this.allowAllUnixSocketsInput,
            }),
            ...(this.hasAllowProjectExtensionChanged && {
              allow_project_extension: this.allowProjectExtensionInput,
            }),
          },
          ...(this.glFeatures.agentArtifactsPage && {
            ai_audit_events_storage_enabled: this.aiAuditEventsStorage,
          }),
        };

        if (this.hasMinimumAccessLevelExecuteSyncChanged) {
          input.ai_settings_attributes.minimum_access_level_execute =
            this.convertMinimumAccessLevelExecuteSync(minimumAccessLevelExecuteSync);
        }

        if (this.hasMinimumAccessLevelExecuteAsyncChanged) {
          input.ai_settings_attributes.minimum_access_level_execute_async =
            minimumAccessLevelExecuteAsync;
        }

        if (this.codeReviewFlowConsentGiven && !this.initialCodeReviewFlowConsentGiven) {
          input.create_code_review_flow_consent = true;
        }

        if (!this.onGeneralSettingsPage) {
          input.duo_core_features_enabled = duoCoreFeaturesEnabled;
          if (namespaceAccessRules !== undefined) {
            input.duo_namespace_access_rules =
              this.formatNamespaceAccessRules(namespaceAccessRules);
          }
        }

        await updateGroupSettings(this.updateId, input);

        const alerts = [
          {
            id: 'organization-group-successfully-updated',
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ];

        if (this.onGeneralSettingsPage) {
          // The expanded SettingsBlock already put its anchor in the URL.
          refreshCurrentPageWithAlerts(alerts);
        } else {
          visitUrlWithAlerts(this.redirectPath, alerts);
        }
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      }
    },
    onAvailabilityChanged(value) {
      this.availability = value;
    },
    onDuoWorkflowMcpChanged(value) {
      this.duoWorkflowMcp = value;
    },
    onAiUsageDataCollectionChanged(value) {
      this.aiUsageDataCollection = value;
    },
    onAiCatalogRestrictedToGroupHierarchyChanged(value) {
      this.aiCatalogRestrictedToGroupHierarchyValue = value;
    },
    onAiAuditEventsStorageChanged(value) {
      this.aiAuditEventsStorage = value;
    },
    onPromptInjectionProtectionChanged(value) {
      this.promptInjectionProtection = value;
    },
    onIncludeRecommendedAllowedDomainsChanged(value) {
      this.includeRecommendedAllowedDomainsInput = value;
    },
    onAllowAllUnixSocketsChanged(value) {
      this.allowAllUnixSocketsInput = value;
    },
    onAllowProjectExtensionChanged(value) {
      this.allowProjectExtensionInput = value;
    },
    formatNamespaceAccessRules(rules) {
      if (!rules) return [];

      return rules.map((rule) => ({
        through_namespace: rule.throughNamespace ? { id: rule.throughNamespace.id } : null,
        features: rule.features,
      }));
    },
    convertMinimumAccessLevelExecuteSync(value) {
      if (value === ACCESS_LEVEL_EVERYONE_INTEGER) {
        return null;
      }

      return value;
    },
  },
};
</script>
<template>
  <ai-common-settings
    :has-parent-form-changed="hasFormChanged"
    @submit="updateSettings"
    @radio-changed="onAvailabilityChanged"
    @code-review-flow-consent-given="onCodeReviewFlowConsentGiven"
  >
    <template #ai-common-settings-tools>
      <duo-tool-settings-form
        :is-mcp-enabled="duoWorkflowMcp"
        :show-mcp="duoWorkflowMcpAvailable"
        @mcp-change="onDuoWorkflowMcpChanged"
      />
    </template>
    <template #ai-common-settings-data-privacy>
      <ai-usage-data-collection-form
        v-if="aiUsageDataCollectionAvailable"
        :disabled-checkbox="disableConfigCheckboxes"
        @change="onAiUsageDataCollectionChanged"
      />
      <ai-catalog-restricted-to-group-hierarchy-form
        v-if="aiCatalogRestrictedToGroupHierarchyAvailable"
        :disabled-checkbox="disableConfigCheckboxes"
        @change="onAiCatalogRestrictedToGroupHierarchyChanged"
      />
      <duo-audit-event-storage-form
        v-if="glFeatures.agentArtifactsPage"
        :disabled-checkbox="disableConfigCheckboxes"
        @change="onAiAuditEventsStorageChanged"
      />
      <duo-workflow-prompt-injection-form
        v-if="showWorkflowSettingsForm"
        :prompt-injection-protection-level="promptInjectionProtection"
        :show-protection="promptInjectionProtectionAvailable"
        @protection-level-change="onPromptInjectionProtectionChanged"
      />
      <network-access-settings
        :group-full-path="groupFullPath"
        :include-recommended-allowed-domains="includeRecommendedAllowedDomainsInput"
        :allow-all-unix-sockets="allowAllUnixSocketsInput"
        :allow-project-extension="allowProjectExtensionInput"
        :disabled-checkbox="disableConfigCheckboxes"
        @include-recommended-allowed-domains-changed="onIncludeRecommendedAllowedDomainsChanged"
        @allow-all-unix-sockets-changed="onAllowAllUnixSocketsChanged"
        @allow-project-extension-changed="onAllowProjectExtensionChanged"
      />
    </template>
  </ai-common-settings>
</template>
