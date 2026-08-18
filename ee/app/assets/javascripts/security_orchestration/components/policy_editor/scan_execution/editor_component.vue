<script>
import {
  GlButton,
  GlEmptyState,
  GlFormRadioGroup,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__, sprintf, n__ } from '~/locale';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  checkForPerformanceRisk,
  hasScheduledRule,
  isGroup,
  extractPolicyContent,
} from 'ee/security_orchestration/components/utils';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import {
  ACTION_SECTION_DISABLE_ERROR,
  ACTIONS_LABEL,
  ADD_ACTION_LABEL,
  CONDITION_SECTION_DISABLE_ERROR,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
} from '../constants';
import EditorLayout from '../editor_layout.vue';
import DisabledSection from '../disabled_section.vue';
import SectionLayout from '../section_layout.vue';
import RuleStrategySelector from './rule/strategy_selector.vue';
import RuleSection from './rule/rule_section.vue';
import OptimizedScanSelector from './action/optimized_scan_selector.vue';
import ScanAction from './action/scan_action.vue';
import {
  addDefaultVariablesToPolicy,
  addDefaultVariablesToManifest,
  buildScannerAction,
  buildDefaultPipeLineRule,
  createPolicyObject,
  getConfiguration,
  getPolicyYaml,
  getPredefinedRuleStrategy,
} from './lib';
import {
  ADD_CONDITION_LABEL,
  CONDITIONS_LABEL,
  DEFAULT_CONDITION_STRATEGY,
  DEFAULT_SCANNER,
  ERROR_MESSAGE_MAP,
  SELECTION_CONFIG_CUSTOM,
  SELECTION_CONFIG_DEFAULT,
} from './constants';

export default {
  name: 'ScanExecutionEditorComponent',
  ACTION: 'actions',
  RULE: 'rules',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  SELECTION_CONFIG_CUSTOM,
  SELECTION_CONFIG_DEFAULT,
  i18n: {
    ACTIONS_LABEL,
    ACTION_SECTION_DISABLE_ERROR,
    ADD_ACTION_LABEL,
    ADD_CONDITION_LABEL,
    CONDITIONS_LABEL,
    CONDITION_SECTION_DISABLE_ERROR,
    PARSING_ERROR_MESSAGE,
    securityScanTitle: s__('SecurityOrchestration|Security scans to execute'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Scan execution policies can only be created by project owners.',
    ),
    exceedingActionsMessage: s__(
      'SecurityOrchestration|Policy has reached the maximum of %{actionsCount} %{actions}',
    ),
    configurationTitle: s__('SecurityOrchestration|Additional configuration'),
    scanExecutionPolicyHelpPage: helpPagePath(
      'user/application_security/policies/scan_execution_policies',
      { anchor: 'scan-execution-policy-editor' },
    ),
  },
  apollo: {
    projectsCount: {
      query: getGroupProjectsCount,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        return data.group?.projects?.count || 0;
      },
      skip() {
        return !isGroup(this.namespaceType) || !hasScheduledRule(this.policy);
      },
      error() {
        this.projectsCount = 0;
      },
    },
  },
  components: {
    DisabledSection,
    EditorLayout,
    GlButton,
    GlEmptyState,
    GlFormRadioGroup,
    GlIcon,
    GlLink,
    GlSprintf,
    OptimizedScanSelector,
    OverloadWarningModal,
    RuleSection,
    RuleStrategySelector,
    ScanAction,
    SectionLayout,
    SkipCiSelector,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespacePath',
    'namespaceType',
    'scanPolicyDocumentationPath',
    'maxScanExecutionPolicyActions',
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
  emits: ['save'],
  data() {
    const yamlEditorValue = this.existingPolicy
      ? policyToYaml(this.existingPolicy, this.selectedPolicyType)
      : getPolicyYaml({ isGroup: isGroup(this.namespaceType) });

    const yamlEditorValueWithVariables = addDefaultVariablesToManifest({
      manifest: yamlEditorValue,
    });
    const { policy, parsingError } = createPolicyObject(yamlEditorValueWithVariables);

    const conditionStrategy =
      (this.existingPolicy && getPredefinedRuleStrategy(policy.rules)) ||
      DEFAULT_CONDITION_STRATEGY;

    return {
      configType: getConfiguration(policy),
      parsingError,
      projectsCount: 0,
      showPerformanceWarningModal: false,
      dismissPerformanceWarningModal: false,
      policy,
      policyModificationAction: null,
      yamlEditorValue: yamlEditorValueWithVariables,
      mode: EDITOR_MODE_RULE,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-execution-policy-editor',
      ),
      specificActionSectionError: '',
      conditionStrategy,
    };
  },
  computed: {
    isDefaultConfig() {
      return this.configType === SELECTION_CONFIG_DEFAULT;
    },
    actionSectionError() {
      return this.specificActionSectionError || this.$options.i18n.ACTION_SECTION_DISABLE_ERROR;
    },
    actions() {
      /**
       * Even though button to add new actions is disabled when limit is reached
       * User can add unlimited number of actions in yaml mode
       * 1000+ actions would hit browser performance and make page slow and unresponsive
       * slicing it to allowed limit would prevent it
       */
      const { actions = [] } = this.policy || {};
      if (this.scanExecutionActionsLimitEnabled) {
        return actions.slice(0, this.maxScanExecutionPolicyActions);
      }

      return actions;
    },
    scanExecutionActionsLimitEnabled() {
      return this.maxScanExecutionPolicyActions !== 0;
    },
    addActionButtonDisabled() {
      return (
        this.scanExecutionActionsLimitEnabled &&
        this.policy.actions?.length >= this.maxScanExecutionPolicyActions
      );
    },
    addActionButtonTitle() {
      const actions = n__('action', 'actions', this.actions?.length);
      return this.addActionButtonDisabled
        ? sprintf(this.$options.i18n.exceedingActionsMessage, {
            actionsCount: this.maxScanExecutionPolicyActions,
            actions,
          })
        : '';
    },
    isValidOptimizedPolicy() {
      return getConfiguration(this.policy) === SELECTION_CONFIG_DEFAULT;
    },
    configurationOptions() {
      return [
        {
          value: SELECTION_CONFIG_DEFAULT,
          disabled: !this.isValidOptimizedPolicy,
          text: s__('SecurityOrchestration|Template'),
        },
        {
          value: SELECTION_CONFIG_CUSTOM,
          disabled: !this.isValidOptimizedPolicy,
          text: s__('SecurityOrchestration|Custom'),
        },
      ];
    },
  },
  methods: {
    areManifestsEqual(manifest) {
      const policyManifest = policyToYaml(this.policy, this.selectedPolicyType);
      return policyManifest === manifest;
    },
    addAction({ scanner = DEFAULT_SCANNER, isOptimized = false } = { scanner: DEFAULT_SCANNER }) {
      if (!this.policy.actions?.length) {
        this.policy = {
          ...this.policy,
          actions: [],
        };
      }

      this.policy.actions.push(
        buildScannerAction({ scanner, isOptimized, withDefaultVariables: true }),
      );
      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      if (!this.policy.rules?.length) {
        this.policy.rules = [];
      }

      this.policy.rules.push(buildDefaultPipeLineRule());
      this.updateYamlEditorValue(this.policy);
    },
    cancelPolicySubmit() {
      this.policyModificationAction = null;
      this.showPerformanceWarningModal = false;
    },
    confirmPolicySubmit() {
      this.showPerformanceWarningModal = false;
      this.dismissPerformanceWarningModal = true;
      this.handleModifyPolicy(this.policyModificationAction);
    },
    removeActionOrRule(type, index) {
      this.policy[type].splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateActionOrRule(type, index, values) {
      this.policy[type].splice(index, 1, values);
      if (type === 'actions') {
        this.policy = addDefaultVariablesToPolicy({ policy: this.policy });
      }
      this.updateYamlEditorValue(this.policy);
    },
    changeEditorMode(mode) {
      this.mode = mode;

      if (mode === EDITOR_MODE_RULE) {
        this.policy = addDefaultVariablesToPolicy({ policy: this.policy });
        this.updateYamlEditorValue(this.policy);

        this.configType = getConfiguration(this.policy);
      }
    },
    handleActionBuilderParsingError(key) {
      this.parsingError = { ...this.parsingError, actions: true };
      this.specificActionSectionError = ERROR_MESSAGE_MAP[key] || '';
    },
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    hasPerformanceRisk() {
      return checkForPerformanceRisk({
        namespaceType: this.namespaceType,
        policy: this.policy,
        projectsCount: this.projectsCount,
      });
    },
    async handleModifyPolicy(action) {
      if (this.hasPerformanceRisk() && !this.dismissPerformanceWarningModal) {
        this.policyModificationAction = action;
        this.showPerformanceWarningModal = true;
        return;
      }

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

      this.$emit('save', { action, policy: policyBodyToYaml(policy) });
    },
    updateConfigType(value) {
      this.configType = value;
    },
    updateOptimizedAction({ enabled, scanner }) {
      if (enabled) {
        this.addAction({ scanner, isOptimized: true });
      } else {
        this.policy.actions = this.policy.actions?.filter((action) => action.scan !== scanner);
        this.updateYamlEditorValue(this.policy);
      }
    },
    updateRuleStrategy({ strategy, rules }) {
      this.conditionStrategy = strategy;
      this.policy.rules = rules;
      this.updateYamlEditorValue(this.policy);
    },
    updateYaml(manifest) {
      if (this.areManifestsEqual(manifest)) {
        return;
      }

      const { policy, parsingError } = createPolicyObject(manifest);
      this.yamlEditorValue = manifest;
      this.policy = policy;
      this.parsingError = parsingError;
      this.specificActionSectionError = '';
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(policy, this.selectedPolicyType);
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
    <template #actions>
      <div class="gl-mt-5">
        <h4>{{ s__('SecurityOrchestration|Scan execution configuration') }}</h4>
        <div class="gl-mb-5">
          <gl-sprintf
            :message="
              s__(
                'SecurityOrchestration|Choose optimization preset %{linkStart}Help me choose%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.i18n.scanExecutionPolicyHelpPage" target="_blank">
                <gl-icon name="information-o" />
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </div>
        <div data-testid="configuration-selection">
          <h5>{{ s__('SecurityOrchestration|Configuration type') }}</h5>
          <gl-form-radio-group
            :checked="configType"
            :options="configurationOptions"
            data-testid="enforcement-selection"
            @input="updateConfigType"
          />
        </div>
        <section-layout class="gl-pt-0" :show-remove-button="false">
          <template #content>
            <div v-if="isDefaultConfig" data-testid="default-action-config">
              <rule-strategy-selector :strategy="conditionStrategy" @changed="updateRuleStrategy" />
              <optimized-scan-selector
                :actions="actions"
                :disabled="addActionButtonDisabled"
                @change="updateOptimizedAction"
              />
            </div>
            <div v-if="!isDefaultConfig" data-testid="custom-action-config">
              <disabled-section
                :disabled="parsingError.actions"
                :error="actionSectionError"
                data-testid="disabled-action"
              >
                <template #title>
                  <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
                </template>

                <scan-action
                  v-for="(action, index) in actions"
                  :key="action.id"
                  :data-testid="`action-${index}`"
                  class="gl-mb-4"
                  :init-action="action"
                  :action-index="index"
                  :error-sources="errorSources"
                  @changed="updateActionOrRule($options.ACTION, index, $event)"
                  @remove="removeActionOrRule($options.ACTION, index)"
                  @parsing-error="handleActionBuilderParsingError"
                />

                <div class="gl-mb-5 gl-rounded-base gl-bg-subtle gl-p-5">
                  <span v-gl-tooltip :title="addActionButtonTitle" data-testid="add-action-wrapper">
                    <gl-button
                      :disabled="addActionButtonDisabled"
                      variant="link"
                      data-testid="add-action"
                      @click="addAction"
                    >
                      {{ $options.i18n.ADD_ACTION_LABEL }}
                    </gl-button>
                  </span>
                </div>
              </disabled-section>
              <disabled-section
                :disabled="parsingError.rules"
                :error="$options.i18n.CONDITION_SECTION_DISABLE_ERROR"
                data-testid="disabled-rule"
              >
                <template #title>
                  <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
                </template>

                <rule-section
                  v-for="(rule, index) in policy.rules"
                  :key="rule.id"
                  :data-testid="`rule-${index}`"
                  class="gl-mb-4"
                  :init-rule="rule"
                  :rule-index="index"
                  @changed="updateActionOrRule($options.RULE, index, $event)"
                  @remove="removeActionOrRule($options.RULE, index)"
                />

                <div class="gl-mb-5 gl-rounded-base gl-bg-subtle gl-p-5">
                  <gl-button variant="link" data-testid="add-rule" @click="addRule">
                    {{ $options.i18n.ADD_CONDITION_LABEL }}
                  </gl-button>
                </div>
              </disabled-section>
            </div>
          </template>
        </section-layout>
      </div>
    </template>

    <template #settings>
      <disabled-section :disabled="false">
        <template #title>
          <h4>{{ $options.i18n.configurationTitle }}</h4>
        </template>

        <skip-ci-selector :skip-ci-configuration="policy.skip_ci" @changed="handleUpdateProperty" />
      </disabled-section>
    </template>

    <template #modal>
      <overload-warning-modal
        :visible="showPerformanceWarningModal"
        @cancel-submit="cancelPolicySubmit"
        @confirm-submit="confirmPolicySubmit"
      />
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
