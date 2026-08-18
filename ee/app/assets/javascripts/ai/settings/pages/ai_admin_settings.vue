<script>
import { updateApplicationSettings } from '~/rest_api';
import axios from '~/lib/utils/axios_utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __, s__ } from '~/locale';
import {
  AVAILABILITY_OPTIONS,
  ACCESS_LEVELS_WITH_EVERYONE_AND_ADMIN,
  AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT,
} from '../constants';
import AiCommonSettings from '../components/ai_common_settings.vue';
import CodeSuggestionsConnectionForm from '../components/code_suggestions_connection_form.vue';
import DuoExpandedLoggingForm from '../components/duo_expanded_logging_form.vue';
import DuoAuditEventStreamingForm from '../components/duo_audit_event_streaming_form.vue';
import DuoChatHistoryExpirationForm from '../components/duo_chat_history_expiration.vue';
import AiModelsForm from '../components/ai_models_form.vue';
import AiGatewayUrlInputForm from '../components/ai_gateway_url_input_form.vue';
import AiGatewayTimeoutInputForm from '../components/ai_gateway_timeout_input_form.vue';
import DuoAgentPlatformServiceUrlInputForm from '../components/duo_agent_platform_service_url_input_form.vue';
import DuoAgentPlatformSecurityForm from '../components/duo_agent_platform_security_form.vue';
import MissingSelfHostedModelsAlert from '../components/missing_self_hosted_models_alert.vue';
import getDuoSettingsQuery from '../../graphql/get_ai_settings.query.graphql';
import NetworkAccessSettings from '../components/network_access_settings.vue';
import updateAiSettingsMutation from '../../graphql/update_ai_settings.mutation.graphql';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
    AiGatewayUrlInputForm,
    AiGatewayTimeoutInputForm,
    DuoAgentPlatformServiceUrlInputForm,
    DuoAgentPlatformSecurityForm,
    MissingSelfHostedModelsAlert,
    NetworkAccessSettings,
    AiModelsForm,
    CodeSuggestionsConnectionForm,
    DuoExpandedLoggingForm,
    DuoAuditEventStreamingForm,
    DuoChatHistoryExpirationForm,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: __(
      'An error occurred while updating your settings. Reload the page to try again.',
    ),
    duoSettingsErrorMessage: s__(
      'AiPowered|An error occurred while loading GitLab Duo settings. Please try again.',
    ),
  },
  inject: [
    'duoAvailability',
    'disabledDirectConnectionMethod',
    'betaSelfHostedModelsEnabled',
    'toggleBetaModelsPath',
    'canManageSelfHostedModels',
    'canManageAigwTimeout',
    'canConfigureAiLogging',
    'duoInstanceModelSelectionPath',
    'showGitlabManagedModelAlert',
    'exposeDuoAgentPlatformServiceUrl',
    'enabledExpandedLogging',
    'aiAuditEventsStreamingEnabled',
    'duoChatExpirationDays',
    'duoChatExpirationColumn',
    'duoCoreFeaturesEnabled',
    'initialDuoCliEnabled',
    'initialMinimumAccessLevelExecuteAsync',
    'initialMinimumAccessLevelExecuteSync',
    'initialDuoTemplateProject',
    'includeRecommendedAllowedDomains',
    'allowAllUnixSockets',
    'allowProjectExtension',
  ],
  provide: {
    isSaaS: false,
  },
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    duoProVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      isLoading: false,
      disabledConnection: this.disabledDirectConnectionMethod,
      aiModelsEnabled: this.betaSelfHostedModelsEnabled,
      aiGatewayUrlInput: '',
      aiGatewayTimeoutSecondsInput: AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT,
      duoAgentPlatformServiceUrlInput: '',
      selfHostedDuoAgentPlatformServiceSecureInput: false,
      expandedLogging: this.enabledExpandedLogging,
      auditEventStreamingEnabled: this.aiAuditEventsStreamingEnabled,
      chatExpirationDays: this.duoChatExpirationDays,
      chatExpirationColumn: this.duoChatExpirationColumn,
      areDuoCoreFeaturesEnabled: this.duoCoreFeaturesEnabled,
      isDuoCliEnabled: this.initialDuoCliEnabled,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
      duoTemplateProject: this.initialDuoTemplateProject,
      duoSettings: null,
      includeRecommendedAllowedDomainsInput: this.includeRecommendedAllowedDomains,
      allowAllUnixSocketsInput: this.allowAllUnixSockets,
      allowProjectExtensionInput: this.allowProjectExtension,
    };
  },
  computed: {
    aiGatewayUrl() {
      return this.duoSettings?.aiGatewayUrl ?? '';
    },
    aiGatewayTimeoutSeconds() {
      return this.duoSettings?.aiGatewayTimeoutSeconds ?? AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT;
    },
    duoAgentPlatformServiceUrl() {
      return this.duoSettings?.duoAgentPlatformServiceUrl ?? '';
    },
    selfHostedDuoAgentPlatformServiceSecureEnabled() {
      return this.duoSettings?.selfHostedDuoAgentPlatformServiceSecure ?? false;
    },
    disableConfigCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    shouldShowManagedModelAlert() {
      if (!this.showGitlabManagedModelAlert) return false;

      const isDuoOff = this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
      if (isDuoOff) return false;

      const aiGatewayInputUpdated =
        this.aiGatewayUrl.trim() === '' && this.aiGatewayUrlInput.trim() !== '';
      const duoAgentPlatformServiceUrlUpdated =
        this.duoAgentPlatformServiceUrl.trim() === '' &&
        this.duoAgentPlatformServiceUrlInput.trim() !== '';

      return aiGatewayInputUpdated || duoAgentPlatformServiceUrlUpdated;
    },
    hasFormChanged() {
      return (
        this.disabledConnection !== this.disabledDirectConnectionMethod ||
        this.hasAiModelsFormChanged ||
        this.haveAiSettingsChanged ||
        this.hasExpandedAiLoggingChanged ||
        this.hasAuditEventStreamingChanged ||
        this.chatExpirationDays !== this.duoChatExpirationDays ||
        this.chatExpirationColumn !== this.duoChatExpirationColumn
      );
    },
    hasAiModelsFormChanged() {
      return this.aiModelsEnabled !== this.betaSelfHostedModelsEnabled;
    },
    haveAiSettingsChanged() {
      return (
        this.aiGatewayUrlInput !== this.aiGatewayUrl ||
        this.duoAgentPlatformServiceUrlInput !== this.duoAgentPlatformServiceUrl ||
        this.selfHostedDuoAgentPlatformServiceSecureInput !==
          this.selfHostedDuoAgentPlatformServiceSecureEnabled ||
        this.areDuoCoreFeaturesEnabled !== this.duoCoreFeaturesEnabled ||
        this.isDuoCliEnabled !== this.initialDuoCliEnabled ||
        this.aiGatewayTimeoutSecondsInput !== this.aiGatewayTimeoutSeconds ||
        this.hasMinimumAccessLevelExecuteAsyncChanged ||
        this.hasMinimumAccessLevelExecuteSyncChanged ||
        this.includeRecommendedAllowedDomainsInput !== this.includeRecommendedAllowedDomains ||
        this.allowAllUnixSocketsInput !== this.allowAllUnixSockets ||
        this.allowProjectExtensionInput !== this.allowProjectExtension
      );
    },
    hasExpandedAiLoggingChanged() {
      return this.expandedLogging !== this.enabledExpandedLogging;
    },
    hasAuditEventStreamingChanged() {
      return this.auditEventStreamingEnabled !== this.aiAuditEventsStreamingEnabled;
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
  apollo: {
    duoSettings: {
      query: getDuoSettingsQuery,
      result({ data }) {
        if (!data?.duoSettings) return;

        const {
          aiGatewayUrl,
          aiGatewayTimeoutSeconds,
          duoAgentPlatformServiceUrl,
          selfHostedDuoAgentPlatformServiceSecure,
        } = data.duoSettings;

        this.aiGatewayUrlInput = aiGatewayUrl ?? '';
        this.aiGatewayTimeoutSecondsInput =
          aiGatewayTimeoutSeconds ?? AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT;
        this.duoAgentPlatformServiceUrlInput = duoAgentPlatformServiceUrl ?? '';
        this.selfHostedDuoAgentPlatformServiceSecureInput =
          selfHostedDuoAgentPlatformServiceSecure ?? false;
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.duoSettingsErrorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
  methods: {
    async updateSettings({
      duoAvailability,
      experimentFeaturesEnabled,
      duoCoreFeaturesEnabled,
      duoCliEnabled,
      promptCacheEnabled,
      duoRemoteFlowsAvailability,
      foundationalAgentsEnabled,
      duoFoundationalFlowsAvailability,
      duoCustomAgentsAvailability,
      duoCustomFlowsAvailability,
      duoExternalAgentsAvailability,
      foundationalAgentsStatuses,
      selectedFoundationalFlowIds,
      duoWorkflowsDefaultImageRegistry,
      duoAgentPlatformEnabled,
      toolApprovalForSessionAvailability,
      namespaceAccessRules,
      minimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync,
      duoTemplateProject,
    }) {
      try {
        this.isLoading = true;

        this.areDuoCoreFeaturesEnabled = duoCoreFeaturesEnabled;
        this.isDuoCliEnabled = duoCliEnabled;
        this.minimumAccessLevelExecuteAsync = minimumAccessLevelExecuteAsync;
        this.minimumAccessLevelExecuteSync = minimumAccessLevelExecuteSync;
        this.duoTemplateProject = duoTemplateProject;

        if (this.haveAiSettingsChanged) {
          await this.updateAiSettings();
        }

        const transformedFoundationalAgentsStatuses = foundationalAgentsStatuses
          ?.filter((agent) => agent.enabled !== null)
          .map((agent) => ({
            reference: agent.reference,
            enabled: agent.enabled,
          }));

        await updateApplicationSettings({
          duo_availability: duoAvailability,
          instance_level_ai_beta_features_enabled: experimentFeaturesEnabled,
          model_prompt_cache_enabled: promptCacheEnabled,
          duo_remote_flows_availability: duoRemoteFlowsAvailability,
          duo_foundational_flows_availability: duoFoundationalFlowsAvailability,
          duo_custom_agents_availability: duoCustomAgentsAvailability,
          duo_custom_flows_availability: duoCustomFlowsAvailability,
          duo_external_agents_availability: duoExternalAgentsAvailability,
          duo_workflows_default_image_registry: duoWorkflowsDefaultImageRegistry,
          enabled_foundational_flows: selectedFoundationalFlowIds,
          disabled_direct_code_suggestions: this.disabledConnection,
          enabled_expanded_logging: this.expandedLogging,
          ai_audit_events_streaming_enabled: this.auditEventStreamingEnabled,
          duo_chat_expiration_days: this.chatExpirationDays,
          duo_chat_expiration_column: this.chatExpirationColumn,
          duo_agent_platform_enabled: duoAgentPlatformEnabled,
          tool_approval_for_session_availability: toolApprovalForSessionAvailability,
          foundational_agents_default_enabled: foundationalAgentsEnabled,
          duo_template_project_id: this.duoTemplateProject?.id ?? null,
          ...this.namespaceAccessRulesPayload(namespaceAccessRules),
          ...(foundationalAgentsStatuses && {
            foundational_agents_statuses: transformedFoundationalAgentsStatuses,
          }),
        });

        if (this.hasAiModelsFormChanged) {
          await this.updateAiModelsSetting();
        }

        visitUrlWithAlerts(this.redirectPath, [
          {
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        this.onError(error);
      } finally {
        this.isLoading = false;
      }
    },
    async updateAiModelsSetting() {
      await axios
        .post(this.toggleBetaModelsPath)
        .catch((error) => {
          this.onError(error);
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
    async updateAiSettings() {
      const input = {
        duoCoreFeaturesEnabled: this.areDuoCoreFeaturesEnabled,
        duoCliEnabled: this.isDuoCliEnabled,
      };

      if (this.hasIncludeRecommendedAllowedChanged) {
        input.includeRecommendedAllowed = this.includeRecommendedAllowedDomainsInput;
      }
      if (this.hasAllowAllUnixSocketsChanged) {
        input.allowAllUnixSockets = this.allowAllUnixSocketsInput;
      }
      if (this.hasAllowProjectExtensionChanged) {
        input.allowProjectExtension = this.allowProjectExtensionInput;
      }

      if (this.hasMinimumAccessLevelExecuteAsyncChanged) {
        input.minimumAccessLevelExecuteAsync =
          ACCESS_LEVELS_WITH_EVERYONE_AND_ADMIN[this.minimumAccessLevelExecuteAsync];
      }
      if (this.hasMinimumAccessLevelExecuteSyncChanged) {
        input.minimumAccessLevelExecute =
          ACCESS_LEVELS_WITH_EVERYONE_AND_ADMIN[this.minimumAccessLevelExecuteSync];
      }

      if (this.canManageSelfHostedModels) {
        input.aiGatewayUrl = this.aiGatewayUrlInput;
        input.duoAgentPlatformServiceUrl = this.duoAgentPlatformServiceUrlInput;
        input.selfHostedDuoAgentPlatformServiceSecure =
          this.selfHostedDuoAgentPlatformServiceSecureInput;
      }

      if (this.canManageAigwTimeout) {
        input.aiGatewayTimeoutSeconds = this.aiGatewayTimeoutSecondsInput;
      }

      const { data } = await this.$apollo.mutate({
        mutation: updateAiSettingsMutation,
        variables: { input },
      });

      if (data) {
        const { errors } = data.duoSettingsUpdate;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }
      }
    },
    onConnectionFormChange(value) {
      this.disabledConnection = value;
    },
    onAiModelsFormChange(value) {
      this.aiModelsEnabled = value;
    },
    onAiGatewayUrlChange(value) {
      this.aiGatewayUrlInput = value;
    },
    onDuoAgentPlatformServiceUrlChange(value) {
      this.duoAgentPlatformServiceUrlInput = value;
    },
    onSelfHostedDuoAgentPlatformServiceSecureChange(value) {
      this.selfHostedDuoAgentPlatformServiceSecureInput = value;
    },
    onAvailabilityChanged(value) {
      this.availability = value;
    },
    onExpandedLoggingChange(value) {
      this.expandedLogging = value;
    },
    onAuditEventStreamingChange(value) {
      this.auditEventStreamingEnabled = value;
    },
    onDuoChatHistoryExpirationDaysChange(value) {
      this.chatExpirationDays = value;
    },
    onDuoChatHistoryExpirationColumnChange(value) {
      this.chatExpirationColumn = value;
    },
    onAiGatewayTimeoutChange(value) {
      this.aiGatewayTimeoutSecondsInput = value;
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
    namespaceAccessRulesPayload(rules) {
      if (rules === undefined || rules === null) return {};

      const formattedRules = rules.map((rule) => ({
        through_namespace: rule.throughNamespace ? { id: rule.throughNamespace.id } : null,
        features: rule.features,
      }));

      return { duo_namespace_access_rules: formattedRules };
    },
    onError(error) {
      createAlert({
        message: error?.message || this.$options.i18n.errorMessage,
        captureError: true,
        error,
      });
    },
  },
};
</script>
<template>
  <ai-common-settings
    :has-parent-form-changed="hasFormChanged"
    @submit="updateSettings"
    @radio-changed="onAvailabilityChanged"
  >
    <template #ai-common-settings-data-privacy>
      <duo-expanded-logging-form
        v-if="canConfigureAiLogging"
        :disabled-checkbox="disableConfigCheckboxes"
        @change="onExpandedLoggingChange"
      />
      <duo-audit-event-streaming-form
        :disabled-checkbox="disableConfigCheckboxes"
        @change="onAuditEventStreamingChange"
      />
      <duo-chat-history-expiration-form
        @change-expiration-days="onDuoChatHistoryExpirationDaysChange"
        @change-expiration-column="onDuoChatHistoryExpirationColumnChange"
      />
      <network-access-settings
        :include-recommended-allowed-domains="includeRecommendedAllowedDomainsInput"
        :allow-all-unix-sockets="allowAllUnixSocketsInput"
        :allow-project-extension="allowProjectExtensionInput"
        :disabled-checkbox="disableConfigCheckboxes"
        @include-recommended-allowed-domains-changed="onIncludeRecommendedAllowedDomainsChanged"
        @allow-all-unix-sockets-changed="onAllowAllUnixSocketsChanged"
        @allow-project-extension-changed="onAllowProjectExtensionChanged"
      />
    </template>

    <template #ai-common-settings-hosting>
      <h2 class="gl-heading-3 gl-mb-2 gl-mt-6" data-testid="hosting-subsection-header">
        {{ s__('AiPowered|Hosting') }}
      </h2>
      <p class="gl-text-subtle" data-testid="hosting-subsection-description">
        {{ s__('AiPowered|Define how your GitLab instance communicates with AI infrastructure.') }}
      </p>

      <code-suggestions-connection-form v-if="duoProVisible" @change="onConnectionFormChange" />

      <ai-gateway-timeout-input-form
        v-if="canManageAigwTimeout"
        :value="aiGatewayTimeoutSecondsInput"
        @change="onAiGatewayTimeoutChange"
      />

      <template v-if="canManageSelfHostedModels">
        <ai-models-form @change="onAiModelsFormChange" />
        <duo-agent-platform-security-form
          v-if="exposeDuoAgentPlatformServiceUrl"
          :value="selfHostedDuoAgentPlatformServiceSecureInput"
          @secure-change="onSelfHostedDuoAgentPlatformServiceSecureChange"
        />

        <h3 class="gl-heading-4 gl-mb-2 gl-mt-6" data-testid="service-endpoints-subsection-header">
          {{ s__('AiPowered|Service endpoints') }}
        </h3>
        <p class="gl-text-subtle">
          {{
            s__('AiPowered|Configure the URLs your GitLab instance uses to connect to AI services.')
          }}
        </p>
        <missing-self-hosted-models-alert
          v-if="shouldShowManagedModelAlert"
          :model-selection-path="duoInstanceModelSelectionPath"
        />
        <ai-gateway-url-input-form :value="aiGatewayUrlInput" @change="onAiGatewayUrlChange" />
        <duo-agent-platform-service-url-input-form
          v-if="exposeDuoAgentPlatformServiceUrl"
          :value="duoAgentPlatformServiceUrlInput"
          @change="onDuoAgentPlatformServiceUrlChange"
        />
      </template>
    </template>
  </ai-common-settings>
</template>
