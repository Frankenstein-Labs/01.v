<script>
import { GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoAvailabilityNamespaces from './duo_availability_namespaces.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from './duo_core_features_form.vue';
import DuoPromptCache from './duo_prompt_cache_form.vue';
import DuoFlowSettings from './duo_flow_settings.vue';
import DuoFoundationalAgentsSettings from './duo_foundational_agents_settings.vue';
import DuoAgentPlatformSettingsForm from './duo_agent_platform_settings_form.vue';
import DuoCustomAgentsAndFlowsSettings from './duo_custom_agents_and_flows_settings.vue';
import ToolApprovalForSessionSettings from './tool_approval_for_session_settings.vue';
import AiNamespaceAccessRules from './ai_namespace_access_rules.vue';
import AiRolePermissions from './ai_role_permissions.vue';
import DuoCliSettings from './duo_cli_settings.vue';
import DuoTemplateProjectSelector from './duo_template_project_selector.vue';

export default {
  name: 'AiCommonSettingsForm',
  components: {
    GlForm,
    GlAlert,
    GlButton,
    AiRolePermissions,
    DuoAvailability,
    DuoAvailabilityNamespaces,
    DuoExperimentBetaFeatures,
    DuoCoreFeaturesForm,
    DuoPromptCache,
    DuoFlowSettings,
    DuoFoundationalAgentsSettings,
    DuoAgentPlatformSettingsForm,
    DuoCustomAgentsAndFlowsSettings,
    ToolApprovalForSessionSettings,
    AiNamespaceAccessRules,
    DuoCliSettings,
    DuoTemplateProjectSelector,
  },
  mixins: [glFeatureFlagMixin()],
  i18n: {
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    duoDisabledSettingsMessageNeverOn: s__(
      'AiPowered|These settings are disabled because GitLab Duo availability is set to always off.',
    ),
    duoDisabledSettingsMessageAlwaysOn: s__(
      'AiPowered|These settings are disabled because GitLab Duo availability is set to always on.',
    ),
    confirmButtonText: __('Save changes'),
    enabled: __('Enabled'),
    disabled: __('Disabled'),
    dataPrivacySectionTitle: s__('AiPowered|Data and privacy'),
  },
  inject: {
    onGeneralSettingsPage: { default: undefined },
    initialMinimumAccessLevelExecuteAsync: { default: undefined },
    initialMinimumAccessLevelExecuteSync: { default: undefined },
    showFoundationalAgentsAvailability: { default: undefined },
    showDuoAgentPlatformEnablementSetting: { default: false },
    isSaaS: { default: false },
    arePromptCacheSettingsAllowed: { default: undefined },
    aiUsageDataCollectionAvailable: { default: undefined },
    duoWorkflowAvailable: { default: undefined },
    promptInjectionProtectionAvailable: { default: undefined },
    canConfigureAiLogging: { default: undefined },
    isGroupSettings: { default: false },
    showDuoTemplateProject: { default: false },
  },
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    duoAgentPlatformEnabled: {
      type: Boolean,
      required: true,
    },
    duoCliEnabled: {
      type: Boolean,
      required: false,
      default: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoFoundationalFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoCustomAgentsAvailability: {
      type: Boolean,
      required: true,
    },
    duoCustomFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoExternalAgentsAvailability: {
      type: Boolean,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
      default: true,
    },
    promptCacheEnabled: {
      type: Boolean,
      required: true,
    },
    foundationalAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    foundationalAgentsStatuses: {
      type: Array,
      required: true,
    },
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedFoundationalFlowIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    toolApprovalForSessionAvailability: {
      type: String,
      required: false,
      default: AVAILABILITY_OPTIONS.DEFAULT_OFF,
    },
    duoWorkflowsDefaultImageRegistry: {
      type: String,
      required: false,
      default: '',
    },
    initialNamespaceAccessRules: {
      type: Array,
      required: false,
      default: null,
    },
    duoTemplateProject: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: [
    'cache-checkbox-changed',
    'change-default-image-registry',
    'change-selected-flow-ids',
    'code-review-flow-consent-given',
    'duo-agent-platform-enabled-changed',
    'duo-cli-enabled-changed',
    'duo-core-checkbox-changed',
    'duo-flow-checkbox-changed',
    'duo-foundational-agents-changed',
    'duo-foundational-agents-statuses-change',
    'duo-foundational-flows-checkbox-changed',
    'duo-custom-agents-changed',
    'duo-custom-flows-changed',
    'duo-external-agents-changed',
    'experiment-checkbox-changed',
    'minimum-access-level-execute-async-changed',
    'minimum-access-level-execute-sync-changed',
    'namespace-access-rules-changed',
    'radio-changed',
    'submit',
    'tool-approval-for-session-changed',
    'change-duo-template-project',
  ],
  data() {
    return {
      availability: this.duoAvailability,
      flowEnabled: this.duoRemoteFlowsAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
      foundationalFlowsEnabled: this.duoFoundationalFlowsAvailability,
      customAgentsAvailability: this.duoCustomAgentsAvailability,
      customFlowsAvailability: this.duoCustomFlowsAvailability,
      externalAgentsAvailability: this.duoExternalAgentsAvailability,
      foundationalAgentsEnabledInput: this.foundationalAgentsEnabled,
      foundationalAgentsStatusesInput: this.foundationalAgentsStatuses,
      duoAgentPlatformEnabledInput: this.duoAgentPlatformEnabled,
      duoCliEnabledInput: this.duoCliEnabled,
      toolApprovalForSessionValue: this.toolApprovalForSessionAvailability,
      hasFoundationalAgentsStatusesChanged: false,
      localSelectedFlowIds: this.selectedFoundationalFlowIds,
      localDefaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
      localDuoTemplateProject: this.duoTemplateProject,
      namespaceAccessRules: this.initialNamespaceAccessRules,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.duoAvailability;
    },
    hasExperimentCheckboxChanged() {
      return this.experimentsEnabled !== this.experimentFeaturesEnabled;
    },
    hasDuoCoreCheckboxChanged() {
      return this.duoCoreEnabled !== this.duoCoreFeaturesEnabled;
    },
    hasCacheCheckboxChanged() {
      return this.cacheEnabled !== this.promptCacheEnabled;
    },
    hasFlowFormChanged() {
      return this.flowEnabled !== this.duoRemoteFlowsAvailability;
    },
    hasFoundationalFlowsFormChanged() {
      return this.foundationalFlowsEnabled !== this.duoFoundationalFlowsAvailability;
    },
    hasCustomAgentsChanged() {
      return this.customAgentsAvailability !== this.duoCustomAgentsAvailability;
    },
    hasCustomFlowsChanged() {
      return this.customFlowsAvailability !== this.duoCustomFlowsAvailability;
    },
    hasExternalAgentsChanged() {
      return this.externalAgentsAvailability !== this.duoExternalAgentsAvailability;
    },
    hasFoundationalAgentsEnabledChanged() {
      return this.foundationalAgentsEnabled !== this.foundationalAgentsEnabledInput;
    },
    hasDuoAgentPlatformEnabledChanged() {
      return this.duoAgentPlatformEnabledInput !== this.duoAgentPlatformEnabled;
    },
    hasDuoCliEnabledChanged() {
      return this.duoCliEnabledInput !== this.duoCliEnabled;
    },
    hasToolApprovalForSessionChanged() {
      return this.toolApprovalForSessionValue !== this.toolApprovalForSessionAvailability;
    },
    hasNamespaceAccessRulesChanged() {
      const currentLength = this.namespaceAccessRules?.length || 0;
      const initialLength = this.initialNamespaceAccessRules?.length || 0;

      if (currentLength !== initialLength) {
        return true;
      }

      return this.namespaceAccessRules?.some((namespaceAccessRule) => {
        const initialNamespaceAccessRule = this.initialNamespaceAccessRules.find(
          (rule) => rule.throughNamespace?.id === namespaceAccessRule.throughNamespace?.id,
        );

        if (!initialNamespaceAccessRule) return true;

        const currentFeatures = [...namespaceAccessRule.features].sort();
        const initialFeatures = [...initialNamespaceAccessRule.features].sort();

        return JSON.stringify(currentFeatures) !== JSON.stringify(initialFeatures);
      });
    },
    hasMinimumAccessLevelExecuteAsyncChanged() {
      return this.minimumAccessLevelExecuteAsync !== this.initialMinimumAccessLevelExecuteAsync;
    },
    hasMinimumAccessLevelExecuteSyncChanged() {
      return this.minimumAccessLevelExecuteSync !== this.initialMinimumAccessLevelExecuteSync;
    },
    hasMinimumAccessLevelExecuteChanged() {
      return (
        this.hasMinimumAccessLevelExecuteAsyncChanged ||
        this.hasMinimumAccessLevelExecuteSyncChanged
      );
    },
    hasDefaultImageRegistryChanged() {
      return this.localDefaultImageRegistry !== this.duoWorkflowsDefaultImageRegistry;
    },
    hasDuoTemplateProjectChanged() {
      const currentId = this.localDuoTemplateProject?.id ?? null;
      const initialId = this.duoTemplateProject?.id ?? null;
      return currentId !== initialId;
    },
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasDuoCoreCheckboxChanged ||
        this.hasCacheCheckboxChanged ||
        this.hasParentFormChanged ||
        this.hasFlowFormChanged ||
        this.hasFoundationalFlowsFormChanged ||
        this.hasFoundationalAgentsEnabledChanged ||
        this.hasFoundationalAgentsStatusesChanged ||
        this.hasSelectedFlowIdsChanged ||
        this.hasDefaultImageRegistryChanged ||
        this.hasDuoAgentPlatformEnabledChanged ||
        this.hasDuoCliEnabledChanged ||
        this.hasToolApprovalForSessionChanged ||
        this.hasCustomAgentsChanged ||
        this.hasCustomFlowsChanged ||
        this.hasExternalAgentsChanged ||
        this.hasNamespaceAccessRulesChanged ||
        this.hasMinimumAccessLevelExecuteChanged ||
        this.hasDuoTemplateProjectChanged
      );
    },
    showWarning() {
      return this.hasAvailabilityChanged && this.warningAvailability;
    },
    warningAvailability() {
      return (
        this.availability === AVAILABILITY_OPTIONS.NEVER_ON ||
        this.availability === AVAILABILITY_OPTIONS.DEFAULT_OFF
      );
    },
    warningMessage() {
      const optsWithWarning = [AVAILABILITY_OPTIONS.DEFAULT_OFF, AVAILABILITY_OPTIONS.NEVER_ON];
      return optsWithWarning.includes(this.availability)
        ? this.$options.i18n.defaultOffWarning
        : '';
    },
    hasDisabledConfigCheckboxes() {
      const disabledStates = [AVAILABILITY_OPTIONS.NEVER_ON, AVAILABILITY_OPTIONS.ALWAYS_ON];
      return disabledStates.includes(this.availability);
    },
    disabledSettingsMessage() {
      if (this.availability === AVAILABILITY_OPTIONS.ALWAYS_ON) {
        return this.$options.i18n.duoDisabledSettingsMessageAlwaysOn;
      }
      return this.$options.i18n.duoDisabledSettingsMessageNeverOn;
    },
    hasSelectedFlowIdsChanged() {
      const current = (this.localSelectedFlowIds || []).slice().sort();
      const initial = (this.selectedFoundationalFlowIds || []).slice().sort();

      return JSON.stringify(current) !== JSON.stringify(initial);
    },
    disableFlowCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    disableExperimentCheckbox() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    disableNamespaceAccessRules() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    disableToolApprovalDropdown() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    agentPlatformChildSettingsDisabled() {
      return !this.duoAgentPlatformEnabledInput || this.disableFlowCheckboxes;
    },
    duoCliSettingsDisabled() {
      return (
        !this.duoAgentPlatformEnabledInput ||
        !this.duoCoreEnabled ||
        this.hasDisabledConfigCheckboxes
      );
    },
    showCoreDisabledMessageAboveDuoCli() {
      return (
        !this.duoCoreEnabled &&
        this.duoAgentPlatformEnabledInput &&
        !this.hasDisabledConfigCheckboxes
      );
    },
    flowSettingsDisabled() {
      if (!this.showDuoAgentPlatformEnablementSetting) {
        return this.disableFlowCheckboxes;
      }

      return this.agentPlatformChildSettingsDisabled;
    },
    shouldShowAiRolePermissionsForGroup() {
      return this.isSaaS && this.glFeatures.dapGroupCustomizablePermissions;
    },
    shouldShowAiRolePermissionsForInstance() {
      return !this.isSaaS && this.glFeatures.dapInstanceCustomizablePermissions;
    },
    shouldShowAiRolePermissions() {
      return (
        (this.shouldShowAiRolePermissionsForGroup || this.shouldShowAiRolePermissionsForInstance) &&
        !this.onGeneralSettingsPage
      );
    },

    showDataPrivacyHeader() {
      return (
        this.arePromptCacheSettingsAllowed ||
        this.aiUsageDataCollectionAvailable ||
        this.duoWorkflowAvailable ||
        this.promptInjectionProtectionAvailable ||
        this.canConfigureAiLogging
      );
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit');
    },
    onMinimumAccessLevelExecuteAsyncChange(role) {
      this.minimumAccessLevelExecuteAsync = role;
      this.$emit('minimum-access-level-execute-async-changed', role);
    },
    onMinimumAccessLevelExecuteSyncChange(role) {
      this.minimumAccessLevelExecuteSync = role;
      this.$emit('minimum-access-level-execute-sync-changed', role);
    },
    onRadioChanged(value) {
      this.availability = value;
      this.$emit('radio-changed', value);
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
      this.$emit('experiment-checkbox-changed', value);
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
      this.$emit('duo-core-checkbox-changed', value);
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
      this.$emit('cache-checkbox-changed', value);
    },
    onFlowCheckboxChanged(value) {
      this.flowEnabled = value;
      this.$emit('duo-flow-checkbox-changed', value);
    },
    onFoundationalFlowsCheckboxChanged(value) {
      this.foundationalFlowsEnabled = value;
      this.$emit('duo-foundational-flows-checkbox-changed', value);
    },
    onFoundationalAgentsEnabledChanged(value) {
      this.foundationalAgentsEnabledInput = value;
      this.$emit('duo-foundational-agents-changed', value);
    },
    onFoundationalAgentsToggled(agentStatuses) {
      this.foundationalAgentsStatusesInput = agentStatuses;
      this.hasFoundationalAgentsStatusesChanged = true;
      this.$emit('duo-foundational-agents-statuses-change', agentStatuses);
    },
    onSelectedFlowIdsChanged(flowIds) {
      this.localSelectedFlowIds = flowIds;
      this.$emit('change-selected-flow-ids', flowIds);
    },
    onCodeReviewFlowConsentGiven() {
      this.$emit('code-review-flow-consent-given');
    },
    onDefaultImageRegistryChanged(value) {
      this.localDefaultImageRegistry = value;
      this.$emit('change-default-image-registry', value);
    },
    onDuoAgentPlatformEnabledChanged(value) {
      this.duoAgentPlatformEnabledInput = value;
      if (value === false) {
        // cascade disable flow and agent settings
        this.onFlowCheckboxChanged(false);
        this.onFoundationalFlowsCheckboxChanged(false);
        this.onFoundationalAgentsEnabledChanged(false);
        this.onCustomAgentsChanged(false);
        this.onCustomFlowsChanged(false);
        this.onExternalAgentsChanged(false);
      }
      this.$emit('duo-agent-platform-enabled-changed', value);
    },
    onDuoCliEnabledChanged(value) {
      this.duoCliEnabledInput = value;
      this.$emit('duo-cli-enabled-changed', value);
    },
    onCustomAgentsChanged(value) {
      this.customAgentsAvailability = value;
      this.$emit('duo-custom-agents-changed', value);
    },
    onCustomFlowsChanged(value) {
      this.customFlowsAvailability = value;
      this.$emit('duo-custom-flows-changed', value);
    },
    onExternalAgentsChanged(value) {
      this.externalAgentsAvailability = value;
      this.$emit('duo-external-agents-changed', value);
    },
    onToolApprovalForSessionChanged(value) {
      this.toolApprovalForSessionValue = value;
      this.$emit('tool-approval-for-session-changed', value);
    },
    onNamespaceAccessRulesChanged(value) {
      this.namespaceAccessRules = value;
      this.$emit('namespace-access-rules-changed', value);
    },
    onDuoTemplateProjectChanged(project) {
      this.localDuoTemplateProject = project;
      this.$emit('change-duo-template-project', project);
    },
  },
};
</script>

<template>
  <gl-form @submit.prevent="submitForm">
    <slot name="ai-common-settings-top"></slot>

    <duo-availability :duo-availability="availability" @change="onRadioChanged" />

    <duo-availability-namespaces />

    <div
      v-if="hasDisabledConfigCheckboxes"
      class="gl-mb-4 gl-rounded-base gl-bg-feedback-info gl-px-4 gl-py-3 gl-text-sm"
      data-testid="duo-disabled-settings-message"
    >
      {{ disabledSettingsMessage }}
    </div>

    <duo-agent-platform-settings-form
      :enabled="duoAgentPlatformEnabledInput"
      :disabled-checkbox="hasDisabledConfigCheckboxes"
      @selected="onDuoAgentPlatformEnabledChanged"
    />

    <duo-core-features-form
      v-if="!onGeneralSettingsPage"
      :duo-core-features-enabled="duoCoreEnabled"
      :disabled-checkbox="hasDisabledConfigCheckboxes"
      :disabled-by-dap="agentPlatformChildSettingsDisabled"
      @change="duoCoreCheckboxChanged"
    />

    <ai-namespace-access-rules
      v-if="initialNamespaceAccessRules && !onGeneralSettingsPage"
      :initial-namespace-access-rules="namespaceAccessRules"
      :disabled-checkbox="disableNamespaceAccessRules"
      @change="onNamespaceAccessRulesChanged"
    />

    <duo-cli-settings
      v-if="!isGroupSettings"
      :duo-cli-enabled="duoCliEnabledInput"
      :disabled="duoCliSettingsDisabled"
      :show-core-disabled-message="showCoreDisabledMessageAboveDuoCli"
      @change="onDuoCliEnabledChanged"
    />

    <duo-foundational-agents-settings
      v-if="showFoundationalAgentsAvailability"
      :foundational-agents-enabled="foundationalAgentsEnabledInput"
      :agent-statuses="foundationalAgentsStatusesInput"
      :read-only="agentPlatformChildSettingsDisabled"
      @change="onFoundationalAgentsEnabledChanged"
      @agent-toggle="onFoundationalAgentsToggled"
    />

    <duo-flow-settings
      :duo-remote-flows-availability="flowEnabled"
      :duo-foundational-flows-availability="foundationalFlowsEnabled"
      :duo-workflows-default-image-registry="duoWorkflowsDefaultImageRegistry"
      :disabled-checkbox="flowSettingsDisabled"
      :selected-foundational-flow-ids="localSelectedFlowIds"
      @change="onFlowCheckboxChanged"
      @change-foundational-flows="onFoundationalFlowsCheckboxChanged"
      @change-selected-flow-ids="onSelectedFlowIdsChanged"
      @change-default-image-registry="onDefaultImageRegistryChanged"
      @change-duo-template-project="onDuoTemplateProjectChanged"
      @consent-given="onCodeReviewFlowConsentGiven"
    />

    <duo-custom-agents-and-flows-settings
      :custom-agents-enabled="customAgentsAvailability"
      :custom-flows-enabled="customFlowsAvailability"
      :external-agents-enabled="externalAgentsAvailability"
      :disabled-checkbox="agentPlatformChildSettingsDisabled"
      @change-custom-agents="onCustomAgentsChanged"
      @change-custom-flows="onCustomFlowsChanged"
      @change-external-agents="onExternalAgentsChanged"
    />

    <tool-approval-for-session-settings
      :tool-approval-for-session-availability="toolApprovalForSessionValue"
      :disabled="disableToolApprovalDropdown"
      @change="onToolApprovalForSessionChanged"
    />

    <ai-role-permissions
      v-if="shouldShowAiRolePermissions"
      :initial-minimum-access-level-execute-async="minimumAccessLevelExecuteAsync"
      :initial-minimum-access-level-execute-sync="minimumAccessLevelExecuteSync"
      @minimum-access-level-execute-async-change="onMinimumAccessLevelExecuteAsyncChange"
      @minimum-access-level-execute-sync-change="onMinimumAccessLevelExecuteSyncChange"
    />

    <duo-template-project-selector
      v-if="showDuoTemplateProject"
      :selected-project="localDuoTemplateProject"
      @project-changed="onDuoTemplateProjectChanged"
    />

    <slot name="ai-common-settings-tools"></slot>

    <template v-if="showDataPrivacyHeader">
      <h2 class="gl-heading-3 gl-mb-2 gl-mt-6" data-testid="data-privacy-subsection-header">
        {{ $options.i18n.dataPrivacySectionTitle }}
      </h2>
      <p class="gl-text-subtle" data-testid="data-privacy-subsection-description">
        {{ s__('AiPowered|Control AI access to your data or external networks.') }}
      </p>
    </template>

    <duo-prompt-cache
      :prompt-cache-enabled="cacheEnabled"
      :disabled-checkbox="hasDisabledConfigCheckboxes"
      class="gl-mb-4"
      @change="onCacheCheckboxChanged"
    />

    <slot name="ai-common-settings-data-privacy"></slot>

    <slot name="ai-common-settings-hosting"></slot>

    <duo-experiment-beta-features
      :experiment-features-enabled="experimentsEnabled"
      :disabled-checkbox="disableExperimentCheckbox"
      @change="experimentCheckboxChanged"
    />

    <slot name="ai-common-settings-bottom"></slot>

    <gl-alert
      v-if="showWarning"
      :dismissible="false"
      variant="warning"
      data-testid="duo-settings-show-warning-alert"
    >
      {{ warningMessage }}
    </gl-alert>
    <gl-button class="gl-mt-6" type="submit" variant="confirm" :disabled="!hasFormChanged">
      {{ $options.i18n.confirmButtonText }}
    </gl-button>
  </gl-form>
</template>
