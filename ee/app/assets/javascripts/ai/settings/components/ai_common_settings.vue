<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import AiCommonSettingsForm from './ai_common_settings_form.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    SettingsBlock,
    AiCommonSettingsForm,
    PageHeading,
  },
  mixins: [glSlotsMixin],
  i18n: {
    confirmButtonText: __('Save changes'),
    settingsBlockTitle: __('GitLab Duo features'),
    settingsBlockDescription: s__(
      'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features%{linkEnd}?',
    ),
    configurationPageTitle: s__('AiPowered|Configuration'),
  },
  inject: [
    'duoAvailability',
    'experimentFeaturesEnabled',
    'duoCoreFeaturesEnabled',
    'onGeneralSettingsPage',
    'promptCacheEnabled',
    'initialDuoRemoteFlowsAvailability',
    'initialDuoFoundationalFlowsAvailability',
    'initialDuoCustomAgentsAvailability',
    'initialDuoCustomFlowsAvailability',
    'initialDuoExternalAgentsAvailability',
    'initialDuoWorkflowsDefaultImageRegistry',
    'foundationalAgentsDefaultEnabled',
    'initialFoundationalAgentsStatuses',
    'initialSelectedFoundationalFlowIds',
    'initialDuoAgentPlatformEnabled',
    'initialDuoCliEnabled',
    'initialToolApprovalForSessionAvailability',
    'initialNamespaceAccessRules',
    'initialMinimumAccessLevelExecuteAsync',
    'initialMinimumAccessLevelExecuteSync',
    'initialDuoTemplateProject',
  ],
  props: {
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['code-review-flow-consent-given', 'radio-changed', 'submit'],
  data() {
    return {
      availability: this.duoAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
      duoRemoteFlowsAvailability: this.initialDuoRemoteFlowsAvailability,
      duoFoundationalFlowsAvailability: this.initialDuoFoundationalFlowsAvailability,
      duoCustomAgentsAvailability: this.initialDuoCustomAgentsAvailability,
      duoCustomFlowsAvailability: this.initialDuoCustomFlowsAvailability,
      duoExternalAgentsAvailability: this.initialDuoExternalAgentsAvailability,
      duoWorkflowsDefaultImageRegistry: this.initialDuoWorkflowsDefaultImageRegistry,
      foundationalAgentsEnabled: this.foundationalAgentsDefaultEnabled,
      selectedFlowIds: this.initialSelectedFoundationalFlowIds || [],
      foundationalAgentsStatuses: this.initialFoundationalAgentsStatuses,
      duoAgentPlatformEnabled: this.initialDuoAgentPlatformEnabled,
      duoCliEnabled: this.initialDuoCliEnabled,
      toolApprovalForSessionAvailability: this.initialToolApprovalForSessionAvailability,
      namespaceAccessRulesChanged: false,
      namespaceAccessRules: this.initialNamespaceAccessRules,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
      duoTemplateProject: this.initialDuoTemplateProject,
    };
  },
  methods: {
    ifChanged(key, value, initialValue) {
      return value === initialValue ? {} : { [key]: value };
    },
    submitForm() {
      const payload = {
        experimentFeaturesEnabled: this.experimentsEnabled,
        duoCoreFeaturesEnabled: this.duoCoreEnabled,
        promptCacheEnabled: this.cacheEnabled,
        // Every availability setter also writes a cascading `lock_*` column, so
        // submitting one an ancestor has locked fails validation even as a
        // no-op. Send them only when the user actually changed them.
        ...this.ifChanged('duoAvailability', this.availability, this.duoAvailability),
        ...this.ifChanged(
          'duoRemoteFlowsAvailability',
          this.duoRemoteFlowsAvailability,
          this.initialDuoRemoteFlowsAvailability,
        ),
        ...this.ifChanged(
          'duoFoundationalFlowsAvailability',
          this.duoFoundationalFlowsAvailability,
          this.initialDuoFoundationalFlowsAvailability,
        ),
        ...this.ifChanged(
          'duoCustomAgentsAvailability',
          this.duoCustomAgentsAvailability,
          this.initialDuoCustomAgentsAvailability,
        ),
        ...this.ifChanged(
          'duoCustomFlowsAvailability',
          this.duoCustomFlowsAvailability,
          this.initialDuoCustomFlowsAvailability,
        ),
        ...this.ifChanged(
          'duoExternalAgentsAvailability',
          this.duoExternalAgentsAvailability,
          this.initialDuoExternalAgentsAvailability,
        ),
        ...this.ifChanged(
          'toolApprovalForSessionAvailability',
          this.toolApprovalForSessionAvailability,
          this.initialToolApprovalForSessionAvailability,
        ),
        duoWorkflowsDefaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
        foundationalAgentsEnabled: this.foundationalAgentsEnabled,
        foundationalAgentsStatuses: this.foundationalAgentsStatuses,
        selectedFoundationalFlowIds: this.selectedFlowIds,
        duoAgentPlatformEnabled: this.duoAgentPlatformEnabled,
        duoCliEnabled: this.duoCliEnabled,
        minimumAccessLevelExecuteAsync: this.minimumAccessLevelExecuteAsync,
        minimumAccessLevelExecuteSync: this.minimumAccessLevelExecuteSync,
        duoTemplateProject: this.duoTemplateProject,
      };

      if (this.namespaceAccessRulesChanged) {
        payload.namespaceAccessRules = this.namespaceAccessRules;
      }

      this.$emit('submit', payload);
    },
    onRadioChanged(value) {
      this.availability = value;
      this.$emit('radio-changed', value);
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
    },
    onDuoFlowChanged(value) {
      this.duoRemoteFlowsAvailability = value;
    },
    onDuoFoundationalFlowsChanged(value) {
      this.duoFoundationalFlowsAvailability = value;
    },
    onDuoCustomAgentsChanged(value) {
      this.duoCustomAgentsAvailability = value;
    },
    onDuoCustomFlowsChanged(value) {
      this.duoCustomFlowsAvailability = value;
    },
    onDuoExternalAgentsChanged(value) {
      this.duoExternalAgentsAvailability = value;
    },
    onFoundationalAgentsEnabledChanged(value) {
      this.foundationalAgentsEnabled = value;
    },
    onDuoAgentPlatformEnabledChanged(value) {
      this.duoAgentPlatformEnabled = value;
    },
    onDuoCliEnabledChanged(value) {
      this.duoCliEnabled = value;
    },
    onToolApprovalForSessionChanged(value) {
      this.toolApprovalForSessionAvailability = value;
    },
    onFoundationalAgentsStatusesChanged(agentStatuses) {
      this.foundationalAgentsStatuses = agentStatuses;
    },
    onSelectedFlowIdsChanged(flowIds) {
      this.selectedFlowIds = flowIds;
    },
    onDefaultImageRegistryChanged(value) {
      this.duoWorkflowsDefaultImageRegistry = value;
    },
    onNamespaceAccessRulesChanged(rules) {
      this.namespaceAccessRulesChanged = true;
      this.namespaceAccessRules = rules;
    },
    onMinimumAccessLevelExecuteAsyncChanged(value) {
      this.minimumAccessLevelExecuteAsync = value;
    },
    onMinimumAccessLevelExecuteSyncChanged(value) {
      this.minimumAccessLevelExecuteSync = value;
    },
    onDuoTemplateProjectChanged(project) {
      this.duoTemplateProject = project;
    },
    onCodeReviewFlowConsentGiven() {
      this.$emit('code-review-flow-consent-given');
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/gitlab_duo/_index'),
};
</script>
<template>
  <div>
    <template v-if="onGeneralSettingsPage">
      <settings-block
        id="js-gitlab-duo-settings"
        class="gl-mb-5 !gl-pt-5"
        :title="$options.i18n.settingsBlockTitle"
      >
        <template #description>
          <gl-sprintf
            data-testid="general-settings-subtitle"
            :message="
              s__(
                'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features%{linkEnd}?',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #default>
          <ai-common-settings-form
            :duo-availability="duoAvailability"
            :duo-remote-flows-availability="initialDuoRemoteFlowsAvailability"
            :duo-foundational-flows-availability="initialDuoFoundationalFlowsAvailability"
            :duo-custom-agents-availability="initialDuoCustomAgentsAvailability"
            :duo-custom-flows-availability="initialDuoCustomFlowsAvailability"
            :duo-external-agents-availability="initialDuoExternalAgentsAvailability"
            :duo-workflows-default-image-registry="initialDuoWorkflowsDefaultImageRegistry"
            :selected-foundational-flow-ids="initialSelectedFoundationalFlowIds"
            :experiment-features-enabled="experimentFeaturesEnabled"
            :duo-core-features-enabled="duoCoreFeaturesEnabled"
            :prompt-cache-enabled="promptCacheEnabled"
            :has-parent-form-changed="hasParentFormChanged"
            :duo-agent-platform-enabled="initialDuoAgentPlatformEnabled"
            :duo-cli-enabled="initialDuoCliEnabled"
            :tool-approval-for-session-availability="initialToolApprovalForSessionAvailability"
            :foundational-agents-enabled="foundationalAgentsDefaultEnabled"
            :foundational-agents-statuses="foundationalAgentsStatuses"
            :duo-template-project="initialDuoTemplateProject"
            @submit="submitForm"
            @radio-changed="onRadioChanged"
            @experiment-checkbox-changed="experimentCheckboxChanged"
            @duo-core-checkbox-changed="duoCoreCheckboxChanged"
            @cache-checkbox-changed="onCacheCheckboxChanged"
            @duo-flow-checkbox-changed="onDuoFlowChanged"
            @duo-agent-platform-enabled-changed="onDuoAgentPlatformEnabledChanged"
            @duo-cli-enabled-changed="onDuoCliEnabledChanged"
            @tool-approval-for-session-changed="onToolApprovalForSessionChanged"
            @duo-foundational-agents-changed="onFoundationalAgentsEnabledChanged"
            @duo-foundational-agents-statuses-change="onFoundationalAgentsStatusesChanged"
            @duo-foundational-flows-checkbox-changed="onDuoFoundationalFlowsChanged"
            @duo-custom-agents-changed="onDuoCustomAgentsChanged"
            @duo-custom-flows-changed="onDuoCustomFlowsChanged"
            @duo-external-agents-changed="onDuoExternalAgentsChanged"
            @change-selected-flow-ids="onSelectedFlowIdsChanged"
            @change-default-image-registry="onDefaultImageRegistryChanged"
            @change-duo-template-project="onDuoTemplateProjectChanged"
            @code-review-flow-consent-given="onCodeReviewFlowConsentGiven"
          >
            <template v-if="glSlots()['ai-common-settings-top']" #ai-common-settings-top>
              <slot name="ai-common-settings-top"></slot>
            </template>
            <template v-if="glSlots()['ai-common-settings-tools']" #ai-common-settings-tools>
              <slot name="ai-common-settings-tools"></slot>
            </template>
            <template
              v-if="glSlots()['ai-common-settings-data-privacy']"
              #ai-common-settings-data-privacy
            >
              <slot name="ai-common-settings-data-privacy"></slot>
            </template>
            <template v-if="glSlots()['ai-common-settings-hosting']" #ai-common-settings-hosting>
              <slot name="ai-common-settings-hosting"></slot>
            </template>
            <template v-if="glSlots()['ai-common-settings-bottom']" #ai-common-settings-bottom>
              <slot name="ai-common-settings-bottom"></slot>
            </template>
          </ai-common-settings-form>
        </template>
      </settings-block>
    </template>
    <template v-else>
      <page-heading :heading="$options.i18n.configurationPageTitle">
        <template #description>
          <span data-testid="configuration-page-subtitle">
            <gl-sprintf :message="$options.i18n.settingsBlockDescription">
              <template #link="{ content }">
                <gl-link :href="$options.aiFeaturesHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>
      </page-heading>
      <ai-common-settings-form
        :duo-availability="duoAvailability"
        :duo-remote-flows-availability="initialDuoRemoteFlowsAvailability"
        :duo-foundational-flows-availability="initialDuoFoundationalFlowsAvailability"
        :duo-custom-agents-availability="initialDuoCustomAgentsAvailability"
        :duo-custom-flows-availability="initialDuoCustomFlowsAvailability"
        :duo-external-agents-availability="initialDuoExternalAgentsAvailability"
        :duo-workflows-default-image-registry="initialDuoWorkflowsDefaultImageRegistry"
        :selected-foundational-flow-ids="initialSelectedFoundationalFlowIds"
        :experiment-features-enabled="experimentFeaturesEnabled"
        :duo-core-features-enabled="duoCoreFeaturesEnabled"
        :prompt-cache-enabled="promptCacheEnabled"
        :has-parent-form-changed="hasParentFormChanged"
        :duo-agent-platform-enabled="initialDuoAgentPlatformEnabled"
        :duo-cli-enabled="initialDuoCliEnabled"
        :tool-approval-for-session-availability="initialToolApprovalForSessionAvailability"
        :foundational-agents-enabled="foundationalAgentsDefaultEnabled"
        :foundational-agents-statuses="foundationalAgentsStatuses"
        :initial-namespace-access-rules="initialNamespaceAccessRules"
        :duo-template-project="initialDuoTemplateProject"
        @submit="submitForm"
        @radio-changed="onRadioChanged"
        @experiment-checkbox-changed="experimentCheckboxChanged"
        @duo-core-checkbox-changed="duoCoreCheckboxChanged"
        @cache-checkbox-changed="onCacheCheckboxChanged"
        @duo-flow-checkbox-changed="onDuoFlowChanged"
        @duo-foundational-flows-checkbox-changed="onDuoFoundationalFlowsChanged"
        @duo-custom-agents-changed="onDuoCustomAgentsChanged"
        @duo-custom-flows-changed="onDuoCustomFlowsChanged"
        @duo-external-agents-changed="onDuoExternalAgentsChanged"
        @duo-agent-platform-enabled-changed="onDuoAgentPlatformEnabledChanged"
        @duo-cli-enabled-changed="onDuoCliEnabledChanged"
        @tool-approval-for-session-changed="onToolApprovalForSessionChanged"
        @duo-foundational-agents-changed="onFoundationalAgentsEnabledChanged"
        @duo-foundational-agents-statuses-change="onFoundationalAgentsStatusesChanged"
        @change-selected-flow-ids="onSelectedFlowIdsChanged"
        @change-default-image-registry="onDefaultImageRegistryChanged"
        @namespace-access-rules-changed="onNamespaceAccessRulesChanged"
        @minimum-access-level-execute-async-changed="onMinimumAccessLevelExecuteAsyncChanged"
        @minimum-access-level-execute-sync-changed="onMinimumAccessLevelExecuteSyncChanged"
        @change-duo-template-project="onDuoTemplateProjectChanged"
        @code-review-flow-consent-given="onCodeReviewFlowConsentGiven"
      >
        <template v-if="glSlots()['ai-common-settings-top']" #ai-common-settings-top>
          <slot name="ai-common-settings-top"></slot>
        </template>
        <template v-if="glSlots()['ai-common-settings-tools']" #ai-common-settings-tools>
          <slot name="ai-common-settings-tools"></slot>
        </template>
        <template
          v-if="glSlots()['ai-common-settings-data-privacy']"
          #ai-common-settings-data-privacy
        >
          <slot name="ai-common-settings-data-privacy"></slot>
        </template>
        <template v-if="glSlots()['ai-common-settings-hosting']" #ai-common-settings-hosting>
          <slot name="ai-common-settings-hosting"></slot>
        </template>
        <template v-if="glSlots()['ai-common-settings-bottom']" #ai-common-settings-bottom>
          <slot name="ai-common-settings-bottom"></slot>
        </template>
      </ai-common-settings-form>
    </template>
  </div>
</template>
