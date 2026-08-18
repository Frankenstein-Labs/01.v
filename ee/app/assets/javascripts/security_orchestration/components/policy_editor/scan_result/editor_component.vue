<script>
import { GlAlert, GlButton, GlCollapse, GlEmptyState, GlTooltipDirective } from '@gitlab/ui';
import { setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__, n__, sprintf } from '~/locale';
import {
  extractPolicyContent,
  isGroup,
  isProject,
} from 'ee/security_orchestration/components/utils';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import {
  ACTION_SECTION_DISABLE_ERROR,
  ADD_ACTION_LABEL,
  BRANCHES_KEY,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  SECURITY_POLICY_ACTIONS,
  PARSING_ERROR_MESSAGE,
  ACTIONS_LABEL,
  ADD_RULE_LABEL,
  RULES_LABEL,
  RULE_SECTION_DISABLE_ERROR,
  MAX_ALLOWED_RULES_LENGTH,
  MAX_ALLOWED_APPROVER_ACTION_LENGTH,
  SETTING_SECTION_DISABLE_ERROR,
} from '../constants';
import DisabledSection from '../disabled_section.vue';
import EditorLayout from '../editor_layout.vue';
import ScanFilterSelector from '../scan_filter_selector.vue';
import SettingsSection from './settings/settings_section.vue';
import ActionSection from './action/action_section.vue';
import BotCommentAction from './action/bot_message_action.vue';
import RuleSection from './rule/rule_section.vue';
import FallbackAndEdgeCasesSection from './advanced_settings/fallback_and_edge_cases_section.vue';
import PolicyExceptions from './advanced_settings/policy_exceptions/policy_exceptions.vue';
import EnforcementType from './enforcement/enforcement_type.vue';
import {
  ACTION_LISTBOX_ITEMS,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  buildAction,
  buildSettingsList,
  createPolicyObject,
  getInvalidBranches,
  getPolicyYaml,
  getSettingAlertConfig,
  emptyBuildRule,
  hasRules,
  humanizeInvalidBranchesError,
  BOT_MESSAGE_TYPE,
  REQUIRE_APPROVAL_TYPE,
  WARN_TYPE,
  ENFORCE_VALUE,
  WARN_VALUE,
  migrateEmptyScannersToAllScanners,
} from './lib';

export default {
  name: 'EditorComponent',
  ACTION_LISTBOX_ITEMS: ACTION_LISTBOX_ITEMS(),
  ADD_RULE_LABEL,
  RULES_LABEL,
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,

  i18n: {
    ACTION_SECTION_DISABLE_ERROR,
    ADD_ACTION_LABEL,
    PARSING_ERROR_MESSAGE,
    RULE_SECTION_DISABLE_ERROR,
    SETTING_SECTION_DISABLE_ERROR,
    accordionTitle: __('Advanced'),
    filterHeaderText: s__('SecurityOrchestration|Choose an action'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Merge request approval policies can only be created by project owners.',
    ),
    settingsTitle: s__('ScanResultPolicy|Override project approval settings'),
    yamlPreview: s__('SecurityOrchestration|.yaml preview'),
    ACTIONS_LABEL,
    exceedingRulesMessage: s__(
      'SecurityOrchestration|You can add a maximum of %{rulesCount} %{rules}.',
    ),
  },
  components: {
    ActionSection,
    BotCommentAction,
    DisabledSection,
    EnforcementType,
    FallbackAndEdgeCasesSection,
    GlAlert,
    GlButton,
    GlCollapse,
    GlEmptyState,
    EditorLayout,
    PolicyExceptions,
    RuleSection,
    ScanFilterSelector,
    SettingsSection,
  },
  directives: { GlTooltip: GlTooltipDirective },
  apollo: {
    linkedSppGroups: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return { fullPath: this.namespacePath };
      },
      update(data) {
        return data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];
      },
      result({ data }) {
        const groups = data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];
        const currentSettingsValue =
          this.policy.approval_settings?.[BLOCK_GROUP_BRANCH_MODIFICATION];
        if (groups.length && currentSettingsValue === undefined) {
          const newSettings = {
            ...(this.policy.approval_settings || {}),
            [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
          };
          this.updateSettings(newSettings);
        }
      },
      skip() {
        return isGroup(this.namespaceType);
      },
    },
  },
  inject: [
    'disableScanPolicyUpdate',
    'namespaceId',
    'namespacePath',
    'namespaceType',
    'policyEditorEmptyStateSvgPath',
    'scanPolicyDocumentationPath',
  ],
  props: {
    errorSources: {
      type: Array,
      required: true,
    },
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isCreating: {
      type: Boolean,
      required: true,
    },
    isDeleting: {
      type: Boolean,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    selectedPolicyType: {
      type: String,
      required: true,
    },
  },
  emits: ['error', 'save'],
  data() {
    const newPolicyYaml = getPolicyYaml({
      isGroup: isGroup(this.namespaceType),
    });

    const yamlEditorValue = this.existingPolicy
      ? policyToYaml(this.existingPolicy, this.selectedPolicyType)
      : newPolicyYaml;

    const { policy, parsingError } = createPolicyObject(yamlEditorValue);

    if (policy.rules) {
      policy.rules = policy.rules.map(migrateEmptyScannersToAllScanners);
    }

    return {
      errors: { action: [] },
      isExpanded: false,
      invalidBranches: [],
      linkedSppGroups: [],
      parsingError,
      policy,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-result-policy-editor',
      ),
      mode: EDITOR_MODE_RULE,
      yamlEditorValue,
    };
  },
  computed: {
    actionError() {
      const actionErrors = this.errorSources.filter(([primaryKey]) => primaryKey === 'action');
      if (actionErrors.length) {
        // Refactor action error messages to be consistent with the other `errorSources`
        // as part of https://gitlab.com/gitlab-org/gitlab/-/issues/486021
        return { action: actionErrors[0][3] };
      }

      return this.errors;
    },
    actions() {
      const actions = this.policy?.actions || [];
      const hasBotAction = actions.some(({ type }) => type === BOT_MESSAGE_TYPE);
      // If the yaml does not have a bot message action, then the bot message will be created as if
      // the bot message action exists and is enabled. Thus, we add it into the actions for rule
      // mode so the user can remove it
      if (hasBotAction) {
        return actions;
      }

      return [...actions, buildAction(BOT_MESSAGE_TYPE)];
    },
    approversActions() {
      return this.actions
        .filter(({ type }) => type === REQUIRE_APPROVAL_TYPE)
        .slice(0, MAX_ALLOWED_APPROVER_ACTION_LENGTH);
    },
    botActions() {
      const botActions = this.actions.filter(({ type }) => type === BOT_MESSAGE_TYPE);
      return botActions.filter(({ enabled }) => enabled);
    },
    explicitBotActions() {
      const botActions = this.policy.actions.filter(({ type }) => type === BOT_MESSAGE_TYPE);
      return botActions.filter(({ enabled }) => enabled);
    },
    enforcement() {
      return this.policy.enforcement_type || ENFORCE_VALUE;
    },
    hasBotActions() {
      return this.botActions.length > 0;
    },
    hasExplicitBotActions() {
      return this.explicitBotActions.length > 0;
    },
    isWarnMode() {
      return this.enforcement === WARN_VALUE;
    },
    icon() {
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    settings() {
      return buildSettingsList({
        settings: this.policy.approval_settings,
        options: {
          hasLinkedGroups: Boolean(this.linkedSppGroups.length),
          namespaceType: this.namespaceType,
        },
      });
    },
    isWithinLimit() {
      return this.policy.rules?.length < MAX_ALLOWED_RULES_LENGTH;
    },
    addRuleTitle() {
      const rules = n__('rule', 'rules', this.policy.rules?.length);
      return sprintf(this.$options.i18n.exceedingRulesMessage, {
        rulesCount: MAX_ALLOWED_RULES_LENGTH,
        rules,
      });
    },
    hasDisabledBotMessageAction() {
      return this.policy.actions?.some(
        ({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled,
      );
    },
    hasRules() {
      return hasRules(this.policy.rules);
    },
    isRuleMode() {
      return this.mode === EDITOR_MODE_RULE;
    },
    allBranches() {
      return this.policy.rules.flatMap((rule) => rule.branches);
    },
    rulesHaveBranches() {
      return this.policy.rules.some(this.ruleHasBranchesProperty);
    },
    settingAlert() {
      return getSettingAlertConfig(this.policy, this.parsingError);
    },
  },
  watch: {
    invalidBranches(branches) {
      if (branches.length > 0) {
        this.$emit('error', humanizeInvalidBranchesError([...branches]));
      } else {
        this.$emit('error', '');
      }
    },
  },
  methods: {
    areManifestsEqual(manifest) {
      const policyManifest = policyToYaml(this.policy, this.selectedPolicyType);
      return policyManifest === manifest;
    },
    ruleHasBranchesProperty(rule) {
      return BRANCHES_KEY in rule;
    },
    addAction(type) {
      if (!this.policy.actions) {
        this.policy = { ...this.policy, actions: [] };
      }

      switch (type) {
        case BOT_MESSAGE_TYPE:
          this.addBotAction();
          break;
        case WARN_TYPE:
        case REQUIRE_APPROVAL_TYPE:
        default:
          this.addApproverAction();
          break;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addApproverAction() {
      const lastApproverActionIndex = this.policy.actions.findLastIndex(
        ({ type }) => type === REQUIRE_APPROVAL_TYPE,
      );
      const nextIndex = lastApproverActionIndex + 1;
      this.policy.actions.splice(nextIndex, 0, buildAction(REQUIRE_APPROVAL_TYPE));
    },
    addBotAction() {
      const action = buildAction(BOT_MESSAGE_TYPE);

      if (this.hasDisabledBotMessageAction) {
        this.updateBotAction(action);
      } else {
        this.policy.actions.push(action);
      }
    },
    removeApproverAction(index) {
      this.policy.actions?.splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateAction(values, index) {
      this.policy.actions.splice(index, 1, values);
      this.errors.action = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateBotAction(values) {
      const actions = this.policy.actions || [];
      const indexOfActionToUpdate = actions.findIndex((a) => a.type === BOT_MESSAGE_TYPE);

      actions.splice(indexOfActionToUpdate, 1, values);
      this.errors.action = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateFallbackAndEdgeCases(property, value) {
      this.parsingError.fallback = false;
      this.handleUpdateProperty(property, value);
    },
    updateSettings(values) {
      if (!this.policy.approval_settings) {
        this.policy = {
          ...this.policy,
          approval_settings: values,
        };
      } else {
        this.policy.approval_settings = values;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      this.policy.rules.push(emptyBuildRule());
      this.updateYamlEditorValue(this.policy);
    },
    removeRule(index) {
      this.policy.rules.splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateRule(ruleIndex, rule) {
      this.policy.rules.splice(ruleIndex, 1, rule);
      this.updateSettings(this.settings);
      this.updateYamlEditorValue(this.policy);
    },
    handleParsingError() {
      this.parsingError = { ...this.parsingError, actions: true };
    },
    async handleModifyPolicy(action) {
      /**
       * backend only accepts the old format
       * policy body is extracted
       * and policy type is added to a policy body
       */
      const policy = extractPolicyContent({
        manifest: this.yamlEditorValue,
        type: this.selectedPolicyType,
        withType: true,
      });

      this.$emit('save', {
        action,
        policy: policyBodyToYaml(policy),
        isRuleMode: this.isRuleMode,
      });
    },
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateEnforcement(value) {
      // if bot comment is disabled or non-existent, add it when going to warn mode
      if (value === WARN_VALUE && !this.hasExplicitBotActions) {
        this.addBotAction();
      }

      this.policy = { ...this.policy, enforcement_type: value };
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    updateYaml(manifest) {
      if (this.areManifestsEqual(manifest)) {
        return;
      }

      const { policy, parsingError } = createPolicyObject(manifest);
      this.yamlEditorValue = manifest;
      this.parsingError = parsingError;
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(policy, this.selectedPolicyType);
    },
    async changeEditorMode(mode) {
      this.mode = mode;
      if (this.isRuleMode) {
        if (this.hasRules && this.isProject && this.rulesHaveBranches) {
          this.invalidBranches = await getInvalidBranches({
            branches: this.allBranches,
            projectId: this.namespaceId,
          });
        }
      }
    },
    shouldDisableActionSelector(filter) {
      const isWarnFilter = filter === WARN_TYPE;
      const isBotFilter = filter === BOT_MESSAGE_TYPE;

      if (this.isWarnMode !== isWarnFilter) {
        return true;
      }

      if (isBotFilter) {
        return this.hasBotActions;
      }

      return this.approversActions.length >= MAX_ALLOWED_APPROVER_ACTION_LENGTH;
    },
    toggleCollapse() {
      this.isExpanded = !this.isExpanded;
    },
    customFilterSelectorTooltip(filter) {
      if (this.isWarnMode) {
        return s__('SecurityOrchestration|No other actions are allowed in warn mode');
      }

      if (filter.value === BOT_MESSAGE_TYPE) {
        return s__(
          'SecurityOrchestration|Merge request approval policies allow a maximum 1 bot message action.',
        );
      }

      if (filter.value === WARN_TYPE) {
        return s__('SecurityOrchestration|Only allowed in warn mode.');
      }

      return s__(
        'SecurityOrchestration|Merge request approval policies allow a maximum of 5 approver actions.',
      );
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :is-editing="isEditing"
    :is-removing-policy="isDeleting"
    :is-updating-policy="isCreating"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy"
    @remove-property="handleRemoveProperty"
    @update-property="handleUpdateProperty"
    @update-yaml="updateYaml"
    @update-editor-mode="changeEditorMode"
  >
    <template #additional-status>
      <enforcement-type :enforcement="enforcement" @change="handleUpdateEnforcement" />
    </template>

    <template #rules>
      <disabled-section
        :disabled="parsingError.rules"
        :error="$options.i18n.RULE_SECTION_DISABLE_ERROR"
        data-testid="disabled-rules"
      >
        <template #title>
          <h4>{{ $options.RULES_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-rounded-base gl-bg-subtle gl-p-6"></div>
        </template>

        <rule-section
          v-for="(rule, index) in policy.rules"
          :key="rule.id"
          class="gl-mb-4"
          :data-testid="`rule-${index}`"
          :error-sources="errorSources"
          :index="index"
          :init-rule="rule"
          @changed="updateRule(index, $event)"
          @remove="removeRule(index)"
        />

        <div class="security-policies-bg-subtle gl-mb-5 gl-rounded-base gl-p-5">
          <span
            v-gl-tooltip="{
              disabled: isWithinLimit,
              title: addRuleTitle,
            }"
            data-testid="add-rule-wrapper"
          >
            <gl-button
              variant="link"
              data-testid="add-rule"
              :disabled="!isWithinLimit"
              @click="addRule"
            >
              {{ $options.ADD_RULE_LABEL }}
            </gl-button>
          </span>
        </div>
      </disabled-section>
    </template>
    <template #actions>
      <disabled-section
        :disabled="parsingError.actions"
        :error="$options.i18n.ACTION_SECTION_DISABLE_ERROR"
        data-testid="disabled-actions"
      >
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-rounded-base gl-bg-subtle gl-p-6"></div>
        </template>

        <action-section
          v-for="(action, index) in approversActions"
          :key="action.id"
          :data-testid="`action-${index}`"
          class="gl-mb-4"
          :action-index="index"
          :init-action="action"
          :is-warn-type="isWarnMode"
          :errors="actionError.action"
          @error="handleParsingError"
          @changed="updateAction($event, index)"
          @remove="removeApproverAction(index)"
        />

        <template v-if="!isWarnMode">
          <bot-comment-action
            v-for="action in botActions"
            :key="action.id"
            class="gl-mb-4"
            :init-action="action"
            @changed="updateBotAction($event)"
          />
        </template>

        <scan-filter-selector
          class="gl-w-full"
          :button-text="$options.i18n.ADD_ACTION_LABEL"
          :header="$options.i18n.filterHeaderText"
          :custom-filter-tooltip="customFilterSelectorTooltip"
          :should-disable-filter="shouldDisableActionSelector"
          :filters="$options.ACTION_LISTBOX_ITEMS"
          @select="addAction"
        />
      </disabled-section>
    </template>
    <template #settings>
      <gl-button
        class="gl-mt-5"
        variant="link"
        :icon="icon"
        data-testid="collapse-button"
        @click="toggleCollapse"
      >
        <h4 class="gl-mr-3">{{ $options.i18n.accordionTitle }}</h4>
      </gl-button>
      <gl-collapse v-model="isExpanded" class="gl-ml-7 gl-mt-0">
        <disabled-section
          :disabled="parsingError.settings"
          :error="$options.i18n.SETTING_SECTION_DISABLE_ERROR"
          data-testid="disabled-settings"
        >
          <template #title>
            <h4>{{ $options.i18n.settingsTitle }}</h4>
          </template>

          <settings-section :rules="policy.rules" :settings="settings" @changed="updateSettings" />
        </disabled-section>

        <policy-exceptions :exceptions="policy.bypass_settings" @changed="handleUpdateProperty" />

        <fallback-and-edge-cases-section
          :has-error="parsingError.fallback"
          :policy="policy"
          @changed="updateFallbackAndEdgeCases"
        />
      </gl-collapse>
      <gl-alert
        v-if="settingAlert.show"
        data-testid="empty-actions-alert"
        class="gl-mb-5"
        :title="settingAlert.config.title"
        :variant="settingAlert.config.variant"
        :dismissible="false"
      >
        {{ settingAlert.config.description }}
      </gl-alert>
    </template>
  </editor-layout>
  <gl-empty-state
    v-else
    :description="$options.i18n.notOwnerDescription"
    :primary-button-link="documentationPath"
    :primary-button-text="$options.i18n.notOwnerButtonText"
    :svg-path="policyEditorEmptyStateSvgPath"
    :svg-height="null"
    title=""
  />
</template>
