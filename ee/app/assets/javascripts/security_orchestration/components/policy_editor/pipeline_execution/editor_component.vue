<script>
import { GlEmptyState } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { setUrlFragment, queryToObject } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import {
  ACTION_SECTION_DISABLE_ERROR,
  ACTIONS_LABEL,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
} from '../constants';
import { doesFileExist, getMergeRequestConfig, policyBodyToYaml, policyToYaml } from '../utils';
import EditorLayout from '../editor_layout.vue';
import DisabledSection from '../disabled_section.vue';
import ActionSection from './action/action_section.vue';
import RuleSection from './rule/rule_section.vue';
import {
  createPolicyObject,
  getInitialPolicy,
  getPipelineConfigStrategyType,
  updatePolicyStrategy,
} from './utils';
import { CONDITIONS_LABEL, DEFAULT_PIPELINE_EXECUTION_POLICY, SCHEDULE } from './constants';

export default {
  name: 'PipelineExecutionEditorComponent',
  ACTION: 'actions',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  i18n: {
    ACTION_SECTION_DISABLE_ERROR,
    ACTIONS_LABEL,
    CONDITIONS_LABEL,
    PARSING_ERROR_MESSAGE,
    notOwnerButtonText: __('Learn more'),
    configurationTitle: s__('SecurityOrchestration|Additional configuration'),
  },
  components: {
    ActionSection,
    DisabledSection,
    GlEmptyState,
    EditorLayout,
    RuleSection,
    SkipCiSelector,
  },
  inject: [
    'disableScanPolicyUpdate',
    'namespacePath',
    'policyEditorEmptyStateSvgPath',
    'scanPolicyDocumentationPath',
  ],
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
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
    let yamlEditorValue;
    let type;

    if (this.existingPolicy) {
      type = this.existingPolicy.type;
      yamlEditorValue = policyToYaml(this.existingPolicy, type);
    } else {
      type = this.selectedPolicyType;
      yamlEditorValue = getInitialPolicy(
        DEFAULT_PIPELINE_EXECUTION_POLICY,
        queryToObject(window.location.search),
      );
    }

    const { policy, parsingError } = createPolicyObject(yamlEditorValue, type);

    return {
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'pipeline-execution-policy-editor',
      ),
      disableSubmit: false,
      mode: EDITOR_MODE_RULE,
      parsingError,
      policy,
      yamlEditorValue,
    };
  },
  computed: {
    content() {
      return this.policy?.content || {};
    },
    isScheduledPolicy() {
      return this.strategy === SCHEDULE;
    },
    schedules() {
      return this.policy?.schedules;
    },
    strategy() {
      return getPipelineConfigStrategyType(this.policy?.pipeline_config_strategy) || SCHEDULE;
    },
  },
  watch: {
    content(newVal) {
      this.handleFileValidation(newVal);
    },
  },
  mounted() {
    if (this.existingPolicy) {
      this.handleFileValidation(this.existingPolicy?.content);
    }
  },
  created() {
    this.handleFileValidation = debounce(this.doesFileExist, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleFileValidation.cancel();
  },
  methods: {
    areManifestsEqual(manifest) {
      const policyManifest = policyToYaml(this.policy, this.policy.type);
      return policyManifest === manifest;
    },
    changeEditorMode(mode) {
      this.mode = mode;
    },
    async handleModifyPolicy(action) {
      const extraMergeRequestInput = getMergeRequestConfig(queryToObject(window.location.search), {
        namespacePath: this.namespacePath,
      });

      /**
       * backend only accepts the old format, so we need to extract the
       * policy body and add the policy type to the policy body
       */
      const policy = extractPolicyContent({
        manifest: this.yamlEditorValue,
        type: this.policy.type,
        withType: true,
      });

      this.$emit('save', { action, extraMergeRequestInput, policy: policyBodyToYaml(policy) });
    },
    async doesFileExist(value) {
      const { project, ref = null, file } = value?.include?.[0] || {};

      try {
        const exists = await doesFileExist({
          fullPath: project,
          filePath: file,
          ref,
        });

        this.disableSubmit = !exists;
      } catch {
        this.disableSubmit = true;
      }
    },
    handleUpdateSchedules(schedule) {
      this.policy = { ...this.policy, schedules: [schedule] };
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateStrategy(strategy) {
      this.policy = updatePolicyStrategy({ policy: this.policy, strategy });
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateYaml(manifest) {
      if (this.areManifestsEqual(manifest)) {
        return;
      }

      // Do not pass in the type to 'createPolicyObject' to ensure we extract the
      // type from the manifest because the type may have changed
      const { policy, parsingError } = createPolicyObject(manifest);
      this.yamlEditorValue = manifest;
      this.parsingError = parsingError;
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      // This method is only ever called after from rule mode, so policy.type will be accurate
      // policy.type would not be accurate if called from yaml mode because you can change
      // type in yaml mode without triggering an update to this.policy
      this.yamlEditorValue = policyToYaml(policy, policy.type);
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
    @update-editor-mode="changeEditorMode"
    @update-property="handleUpdateProperty"
    @update-yaml="handleUpdateYaml"
  >
    <template #rules>
      <disabled-section data-testid="disabled-rule">
        <template #title>
          <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
        </template>
        <rule-section
          class="gl-mb-4"
          :error-sources="errorSources"
          :strategy="strategy"
          :schedules="schedules"
          @changed="handleUpdateSchedules"
        />
      </disabled-section>
    </template>

    <template #actions-first>
      <disabled-section
        :disabled="parsingError.actions"
        :error="$options.i18n.ACTION_SECTION_DISABLE_ERROR"
        data-testid="disabled-action"
      >
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>
        <action-section
          class="security-policies-bg-subtle gl-mb-4 gl-rounded-base gl-p-5"
          :action="content"
          :does-file-exist="!disableSubmit"
          :strategy="strategy"
          :suffix="policy.suffix"
          :variables-override="policy.variables_override"
          @changed="handleUpdateProperty"
          @update-strategy="handleUpdateStrategy"
        />
      </disabled-section>
    </template>

    <template #settings>
      <disabled-section v-if="!isScheduledPolicy" :disabled="false">
        <template #title>
          <h4>{{ $options.i18n.configurationTitle }}</h4>
        </template>

        <skip-ci-selector
          is-reversed
          :skip-ci-configuration="policy.skip_ci"
          @changed="handleUpdateProperty"
        />
      </disabled-section>
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
