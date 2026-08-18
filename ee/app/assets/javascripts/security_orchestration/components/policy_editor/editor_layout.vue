<script>
import { defineAsyncComponent } from 'vue';
import {
  GlAlert,
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlFormRadioGroup,
  GlFormTextarea,
  GlIcon,
  GlModal,
  GlModalDirective,
  GlSegmentedControl,
  GlTooltipDirective,
} from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { __, s__, sprintf } from '~/locale';
import DimDisableContainer from 'ee/security_orchestration/components/policy_editor/dim_disable_container.vue';
import ScopeSection from 'ee/security_orchestration/components/policy_editor/scope/scope_section.vue';
import PanelResizer from '~/vue_shared/components/panel_resizer.vue';
import EditorLayoutCollapseHeader from 'ee/security_orchestration/components/policy_editor/editor_layout_collapse_header.vue';
import { NAMESPACE_TYPES } from '../../constants';
import { APPROVAL_POLICY_TYPE, POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';
import {
  DELETE_MODAL_CONFIG,
  EDITOR_MODES,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  POLICY_RUN_TIME_MESSAGE,
  POLICY_RUN_TIME_TOOLTIP,
  SCOPE_LABEL,
  SPLIT_VIEW_MAX_WIDTH,
  SPLIT_VIEW_MIN_WIDTH,
  RULE_SECTION_INITIAL_WIDTH,
  RULE_SECTION_COLLAPSED_WIDTH,
  SPLIT_VIEW_HALF_WIDTH,
  RULE_SECTION_MAX_WIDTH,
} from './constants';
import { getPolicyLimitDetails } from './utils';

const { scanExecution, legacyApproval, approval, vulnerabilityManagement, pipelineExecution } =
  POLICY_TYPE_COMPONENT_OPTIONS;

const POLICY_EDITOR_SPLIT_VIEW_WIDTH_LOCAL_STORAGE_KEY = 'policies_editor_split_view_width';

export default {
  name: 'EditorLayout',
  SPLIT_VIEW_MAX_WIDTH,
  SPLIT_VIEW_MIN_WIDTH,
  RULE_SECTION_INITIAL_WIDTH,
  RULE_SECTION_COLLAPSED_WIDTH,
  SPLIT_VIEW_HALF_WIDTH,
  RULE_SECTION_MAX_WIDTH,
  i18n: {
    DELETE_MODAL_CONFIG,
    POLICY_RUN_TIME_MESSAGE,
    POLICY_RUN_TIME_TOOLTIP,
    SCOPE_LABEL,
    description: __('Description'),
    failedValidationText: __('This field is required'),
    name: __('Name'),
    newProjectInfo: s__(
      'SecurityOrchestration|A new project will be created to be used to store security policies. If a project already exists with security policies, link it via the policy list page.',
    ),
    toggleLabel: s__('SecurityOrchestration|Policy status'),
    yamlPreview: s__('SecurityOrchestration|.yaml preview'),
    rulesHeader: s__('SecurityOrchestration|Rules'),
    yamlHeader: s__('SecurityOrchestration|Yaml'),
    resizerLabel: s__("SecurityOrchestration|Drag with a mouse to adjust editor's width"),
    saveExistingPolicyText: s__('SecurityOrchestration|Update via merge request'),
    saveNewPolicyText: __('Configure with a merge request'),
    saveNewProjectAndPolicyText: s__(
      'SecurityOrchestration|Create new project with the new policy',
    ),
  },
  STATUS_OPTIONS: [
    { value: true, text: __('Enabled') },
    { value: false, text: __('Disabled') },
  ],
  components: {
    EditorLayoutCollapseHeader,
    DimDisableContainer,
    ScopeSection,
    GlAlert,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlFormRadioGroup,
    GlIcon,
    GlModal,
    GlSegmentedControl,
    PanelResizer,
    YamlEditor: defineAsyncComponent(
      () => import(/* webpackChunkName: 'policy_yaml_editor' */ '../yaml_editor.vue'),
    ),
  },
  directives: { GlModal: GlModalDirective, GlTooltip: GlTooltipDirective },
  inject: [
    'assignedPolicyProject',
    'namespaceType',
    'policiesPath',
    'maxActiveScanExecutionPoliciesReached',
    'maxScanExecutionPoliciesAllowed',
    'maxActiveScanResultPoliciesReached',
    'maxScanResultPoliciesAllowed',
    'maxActiveVulnerabilityManagementPoliciesReached',
    'maxVulnerabilityManagementPoliciesAllowed',
    'maxActivePipelineExecutionPoliciesReached',
    'maxPipelineExecutionPoliciesAllowed',
    'policyEditorEnabled',
  ],
  props: {
    defaultEditorMode: {
      type: String,
      required: false,
      default: EDITOR_MODE_RULE,
    },
    editorModes: {
      type: Array,
      required: false,
      default: () => EDITOR_MODES,
    },
    hasParsingError: {
      type: Boolean,
      required: false,
      default: false,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    isRemovingPolicy: {
      type: Boolean,
      required: false,
      default: false,
    },
    isUpdatingPolicy: {
      type: Boolean,
      required: false,
      default: false,
    },
    parsingError: {
      type: String,
      required: false,
      default: '',
    },
    policy: {
      type: Object,
      required: true,
    },
    yamlEditorValue: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: [
    'remove-policy',
    'remove-property',
    'save-policy',
    'update-editor-mode',
    'update-property',
    'update-yaml',
  ],
  data() {
    return {
      ruleWidth: this.getRuleWidth(),
      isInitiallyEnabled: this.policy.enabled,
      selectedEditorMode: this.defaultEditorMode,
      showValidation: false,
      ruleCollapsed: false,
      yamlCollapsed: false,
    };
  },
  computed: {
    hasResetButton() {
      return this.ruleWidth !== RULE_SECTION_INITIAL_WIDTH;
    },
    computedRuleWidth() {
      return this.hasNewSplitView ? { width: `${this.ruleWidth}px` } : {};
    },
    computedYamlWidth() {
      const width = this.$options.SPLIT_VIEW_MAX_WIDTH - this.ruleWidth;
      return this.hasNewSplitView ? { width: `${width}px` } : {};
    },
    hasNewSplitView() {
      return this.policyEditorEnabled;
    },
    hasSPP() {
      return !isEmpty(this.assignedPolicyProject);
    },
    layoutClass() {
      if (this.hasNewSplitView) {
        return 'security-policies-split-view';
      }

      return 'security-policies';
    },
    policyType() {
      return Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        (policy) => policy.urlParameter === this.policy.type,
      );
    },
    policyLimitArgs() {
      switch (this.policyType) {
        case scanExecution:
          return {
            policyLimitReached: this.maxActiveScanExecutionPoliciesReached,
            policyLimit: this.maxScanExecutionPoliciesAllowed,
          };
        case legacyApproval:
        case approval:
          return {
            policyLimitReached: this.maxActiveScanResultPoliciesReached,
            policyLimit: this.maxScanResultPoliciesAllowed,
          };
        case vulnerabilityManagement:
          return {
            policyLimitReached: this.maxActiveVulnerabilityManagementPoliciesReached,
            policyLimit: this.maxVulnerabilityManagementPoliciesAllowed,
          };
        case pipelineExecution:
          return {
            policyLimitReached: this.maxActivePipelineExecutionPoliciesReached,
            policyLimit: this.maxPipelineExecutionPoliciesAllowed,
          };
        default:
          return {};
      }
    },
    policyLimitDetails() {
      const { policyLimit, policyLimitReached } = this.policyLimitArgs;
      return getPolicyLimitDetails({
        type: this.policyType?.text?.toLowerCase() || scanExecution.text.toLowerCase(),
        policyLimit,
        policyLimitReached,
        initialValue: this.isInitiallyEnabled,
      });
    },
    deleteModalTitle() {
      return sprintf(s__('SecurityOrchestration|Delete policy: %{policy}'), {
        policy: this.policy.name,
      });
    },
    hasValidName() {
      return this.policy.name !== '';
    },
    saveButtonText() {
      if (this.isEditing) {
        return this.$options.i18n.saveExistingPolicyText;
      }

      return this.hasSPP
        ? this.$options.i18n.saveNewPolicyText
        : this.$options.i18n.saveNewProjectAndPolicyText;
    },
    shouldShowRuleEditor() {
      return this.selectedEditorMode === EDITOR_MODE_RULE;
    },
    shouldShowYamlEditor() {
      return this.selectedEditorMode === EDITOR_MODE_YAML;
    },
    shouldShowRuntimeMessage() {
      return (
        this.policy.type === APPROVAL_POLICY_TYPE && this.namespaceType !== NAMESPACE_TYPES.PROJECT
      );
    },
  },
  watch: {
    selectedEditorMode(val) {
      this.$emit('update-editor-mode', val);
    },
  },
  methods: {
    removePolicy() {
      this.$emit('remove-policy');
    },
    savePolicy() {
      this.$emit('save-policy');
    },
    removeProperty(property) {
      this.$emit('remove-property', property);
    },
    updateProperty(property, value) {
      if (property === 'name') {
        this.showValidation = true;
      }

      this.$emit('update-property', property, value);
    },
    updateYaml(manifest) {
      this.$emit('update-yaml', manifest);
    },
    cacheTreeListWidth(size) {
      localStorage.setItem(POLICY_EDITOR_SPLIT_VIEW_WIDTH_LOCAL_STORAGE_KEY, size);
    },
    collapseRule(collapsed) {
      this.ruleCollapsed = collapsed;

      if (this.yamlCollapsed) {
        this.yamlCollapsed = false;
      }

      this.ruleWidth = collapsed ? this.$options.RULE_SECTION_COLLAPSED_WIDTH : this.getRuleWidth();
    },
    collapseYaml(collapsed) {
      this.yamlCollapsed = collapsed;

      if (this.ruleCollapsed) {
        this.ruleCollapsed = false;
      }

      this.ruleWidth = collapsed
        ? this.$options.RULE_SECTION_MAX_WIDTH
        : this.$options.SPLIT_VIEW_HALF_WIDTH;
    },
    resetToDefaultSize() {
      this.ruleWidth = this.$options.RULE_SECTION_INITIAL_WIDTH;
      this.cacheTreeListWidth(this.$options.RULE_SECTION_INITIAL_WIDTH);
      this.ruleCollapsed = false;
      this.yamlCollapsed = false;
    },
    getRuleWidth() {
      return (
        parseInt(localStorage.getItem(POLICY_EDITOR_SPLIT_VIEW_WIDTH_LOCAL_STORAGE_KEY), 10) ||
        this.$options.RULE_SECTION_INITIAL_WIDTH
      );
    },
  },
};
</script>

<template>
  <section :class="layoutClass" class="gl-mt-6 gl-flex gl-flex-col @lg/panel:gl-grid">
    <div class="gl-mb-5">
      <div
        v-if="!hasNewSplitView"
        class="gl-mb-6 gl-border-b-1 gl-border-default gl-pb-6 gl-border-b-solid"
      >
        <gl-segmented-control v-model="selectedEditorMode" :options="editorModes" />
      </div>
      <div class="gl-flex gl-flex-col @lg/panel:gl-flex-row">
        <section
          class="gl-w-full"
          data-testid="rule-section"
          :class="{ 'gl-relative @lg/panel:gl-pr-6': hasNewSplitView }"
          :style="computedRuleWidth"
        >
          <editor-layout-collapse-header
            v-if="hasNewSplitView"
            class="gl-mb-4 gl-hidden @lg/panel:gl-flex"
            :has-reset-button="hasResetButton"
            :header="$options.i18n.rulesHeader"
            :collapsed="ruleCollapsed"
            @reset-size="resetToDefaultSize"
            @toggle="collapseRule"
          />
          <slot name="modal"></slot>
          <div v-if="shouldShowRuleEditor && !ruleCollapsed" data-testid="rule-editor">
            <gl-alert v-if="hasParsingError" class="gl-mb-5" variant="warning" :dismissible="false">
              {{ parsingError }}
            </gl-alert>

            <gl-form-group
              :label="$options.i18n.name"
              label-for="policyName"
              :invalid-feedback="$options.i18n.failedValidationText"
            >
              <gl-form-input
                id="policyName"
                data-testid="policy-name-text"
                :disabled="hasParsingError"
                :state="hasValidName || !showValidation"
                :value="policy.name"
                required
                @input="updateProperty('name', $event)"
              />
            </gl-form-group>

            <gl-form-group
              :label="$options.i18n.description"
              label-for="policyDescription"
              optional
            >
              <gl-form-textarea
                id="policyDescription"
                data-testid="policy-description-text"
                :disabled="hasParsingError"
                :value="policy.description"
                no-resize
                @input="updateProperty('description', $event)"
              />
            </gl-form-group>

            <gl-form-group
              :label="$options.i18n.toggleLabel"
              :disabled="hasParsingError"
              class="gl-mb-0"
            >
              <gl-form-radio-group
                v-gl-tooltip="{
                  disabled: !policyLimitDetails.radioButton.disabled,
                  title: policyLimitDetails.radioButton.text,
                }"
                class="gl-inline-block"
                :options="$options.STATUS_OPTIONS"
                :disabled="hasParsingError || policyLimitDetails.radioButton.disabled"
                :checked="policy.enabled"
                @change="updateProperty('enabled', $event)"
              />
            </gl-form-group>

            <slot name="additional-status"></slot>

            <dim-disable-container :disabled="hasParsingError">
              <template #title>
                <h4>{{ $options.i18n.SCOPE_LABEL }}</h4>
              </template>

              <template #disabled>
                <div class="gl-rounded-base gl-bg-subtle gl-p-6"></div>
              </template>

              <scope-section
                :policy-scope="policy.policy_scope"
                @changed="updateProperty('policy_scope', $event)"
                @remove="removeProperty('policy_scope')"
              />
            </dim-disable-container>

            <slot name="actions-first"></slot>
            <slot name="rules"></slot>
            <slot name="actions"></slot>
            <slot name="settings"></slot>
          </div>
          <yaml-editor
            v-if="shouldShowYamlEditor"
            data-testid="policy-yaml-editor"
            :policy-type="policy.type"
            :value="yamlEditorValue"
            :read-only="false"
            @input="updateYaml"
          />

          <panel-resizer
            v-if="!yamlCollapsed && !ruleCollapsed"
            custom-class="security-policies-drag-handle"
            class="gl-hidden @lg/panel:gl-block"
            :size.sync="ruleWidth"
            :start-size="ruleWidth"
            :min-size="$options.SPLIT_VIEW_MIN_WIDTH"
            :max-size="$options.RULE_SECTION_INITIAL_WIDTH"
            side="right"
            @resize-end="cacheTreeListWidth"
            @reset-size="resetToDefaultSize"
          >
            <template #thumbnail>
              <gl-button
                class="security-policies-drag-thumbnail !gl-min-h-7 !gl-min-w-5 !gl-rounded-none !gl-border-0 !gl-bg-strong"
                :aria-label="$options.i18n.resizerLabel"
                icon="grip"
                size="small"
              />
            </template>
          </panel-resizer>
        </section>
      </div>

      <p
        v-if="shouldShowRuntimeMessage && !hasNewSplitView"
        class="gl-mb-0 gl-mt-5"
        data-testid="scan-result-policy-run-time-info"
      >
        <gl-icon v-gl-tooltip="$options.i18n.POLICY_RUN_TIME_TOOLTIP" name="information-o" />
        {{ $options.i18n.POLICY_RUN_TIME_MESSAGE }}
      </p>

      <div
        class="security-policies-actions gl-flex gl-flex-col gl-flex-wrap gl-items-baseline gl-gap-3"
        :class="{ 'security-policies-actions-sidebar': ruleCollapsed }"
      >
        <p
          v-if="shouldShowRuntimeMessage && hasNewSplitView"
          class="gl-mb-0 gl-mt-5"
          data-testid="scan-result-policy-run-time-info"
        >
          <gl-icon v-gl-tooltip="$options.i18n.POLICY_RUN_TIME_TOOLTIP" name="information-o" />
          {{ $options.i18n.POLICY_RUN_TIME_MESSAGE }}
        </p>

        <p v-if="!hasSPP" class="gl-mb-0 gl-mt-5" data-testid="no-spp-info">
          <gl-icon name="information-o" /> {{ $options.i18n.newProjectInfo }}
        </p>

        <div
          class="gl-mt-5 gl-flex gl-w-full gl-grow gl-flex-wrap gl-gap-3"
          :class="{ '!gl-mt-3': shouldShowRuntimeMessage }"
        >
          <gl-button
            type="submit"
            variant="confirm"
            data-testid="save-policy"
            :loading="isUpdatingPolicy"
            @click="savePolicy"
          >
            {{ saveButtonText }}
          </gl-button>
          <gl-button category="secondary" :href="policiesPath">
            {{ __('Cancel') }}
          </gl-button>

          <gl-button
            v-if="isEditing"
            v-gl-modal="'delete-modal'"
            class="gl-self-end @md/panel:gl-ml-auto"
            category="secondary"
            variant="danger"
            data-testid="delete-policy"
            :loading="isRemovingPolicy"
          >
            {{ s__('SecurityOrchestration|Delete policy') }}
          </gl-button>
        </div>
      </div>
    </div>

    <aside
      class="security-policies-sidebar gl-pl-0 @lg/panel:gl-pl-3"
      data-testid="yaml-section"
      :class="{ '!gl-pl-0': ruleCollapsed, 'gl-mb-4 @lg/panel:gl-mb-0': hasNewSplitView }"
      :style="computedYamlWidth"
    >
      <section
        v-if="shouldShowRuleEditor && !hasNewSplitView"
        class="security-policies-preview security-policies-bg-subtle gl-p-5"
        data-testid="rule-editor-preview"
      >
        <h5>{{ $options.i18n.yamlPreview }}</h5>
        <pre
          class="security-policies-bg-subtle gl-whitespace-pre-wrap gl-border-none gl-p-0"
          :class="{ 'gl-opacity-5': hasParsingError }"
          data-testid="rule-editor-preview-content"
          >{{ yamlEditorValue }}</pre>
      </section>
      <section v-if="hasNewSplitView">
        <editor-layout-collapse-header
          v-if="hasNewSplitView"
          class="gl-mb-4"
          is-right
          :header="$options.i18n.yamlHeader"
          :collapsed="yamlCollapsed"
          @toggle="collapseYaml"
        />

        <yaml-editor
          v-if="!yamlCollapsed"
          data-testid="policy-yaml-editor"
          :policy-type="policy.type"
          :value="yamlEditorValue"
          :read-only="false"
          @input="updateYaml"
        />
      </section>
    </aside>

    <gl-modal
      modal-id="delete-modal"
      :title="deleteModalTitle"
      :action-secondary="$options.i18n.DELETE_MODAL_CONFIG.secondary"
      :action-cancel="$options.i18n.DELETE_MODAL_CONFIG.cancel"
      @secondary="removePolicy"
    >
      {{
        s__(
          'SecurityOrchestration|Are you sure you want to delete this policy? This action cannot be undone.',
        )
      }}
    </gl-modal>
  </section>
</template>
