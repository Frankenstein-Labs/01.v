<script>
import { GlButton, GlSprintf, GlCollapsibleListbox } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  ALL_PROTECTED_BRANCHES,
  BRANCH_EXCEPTIONS_KEY,
  SCAN_EXECUTION_BRANCH_TYPE_OPTIONS,
  SPECIFIC_BRANCHES,
  TARGET_BRANCHES,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { handleBranchTypeSelect } from '../lib';
import {
  PIPELINE_SOURCES_KEY,
  SCAN_EXECUTION_RULES_LABELS,
  SCAN_EXECUTION_RULES_PIPELINE_KEY,
  SCAN_EXECUTION_RULES_SCHEDULE_KEY,
} from '../constants';
import BranchExceptionSelector from '../../branch_exception_selector.vue';
import BranchTypeSelector from './branch_type_selector.vue';
import PipelineSourceSelector from './pipeline_source_selector.vue';

export default {
  BRANCH_EXCEPTIONS_KEY,
  PIPELINE_SOURCES_KEY,
  SCAN_EXECUTION_RULES_LABELS,
  i18n: {
    selectedBranchesPlaceholder: s__('ScanExecutionPolicy|Select branches'),
  },
  name: 'BaseRuleComponent',
  components: {
    BranchExceptionSelector,
    BranchTypeSelector,
    GlButton,
    GlCollapsibleListbox,
    GlSprintf,
    PipelineSourceSelector,
  },
  mixins: [glFeatureFlagMixin(), glSlotsMixin],
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
    defaultSelectedRule: {
      type: String,
      required: false,
      default: SCAN_EXECUTION_RULES_PIPELINE_KEY,
    },
    isBranchScope: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['changed', 'remove', 'select-rule'],
  data() {
    let selectedBranchType = ALL_PROTECTED_BRANCHES.value;

    if (this.initRule.branch_type) {
      selectedBranchType = this.initRule.branch_type;
    }

    if (this.initRule.branches) {
      selectedBranchType = SPECIFIC_BRANCHES.value;
    }

    return {
      selectedRule: this.defaultSelectedRule[this.selectedKey],
      selectedKey: this.defaultSelectedRule,
      selectedBranchType,
    };
  },
  computed: {
    branchesLabel() {
      if (!this.initRule.branches) {
        return '';
      }

      return this.initRule.branches.some((branch) => branch.includes('*'))
        ? s__('SecurityOrchestration|branches')
        : n__('branch', 'branches', this.initRule.branches.length);
    },
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    pipelineSources() {
      return this.initRule.pipeline_sources || {};
    },
    rulesListBoxItems() {
      return Object.entries(this.$options.SCAN_EXECUTION_RULES_LABELS).map(([value, text]) => ({
        value,
        text,
      }));
    },
    branchesToAdd() {
      return (this.initRule.branches?.length || 0) === 0
        ? ''
        : this.initRule.branches?.filter((element) => element?.trim()).join(',');
    },
    branchTypes() {
      return SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({
        namespaceType: this.namespaceType,
        includeTargetTypes: !this.isScheduleType,
      });
    },
    isScheduleType() {
      return this.initRule.type === SCAN_EXECUTION_RULES_SCHEDULE_KEY;
    },
    message() {
      // Handle non-pipeline rules first
      if (this.isScheduleType) {
        return s__(
          'ScanExecutionPolicy|%{rules} actions for %{scopes} %{branches} %{agents} %{branchExceptions} %{namespaces} %{period}',
        );
      }

      // Default pipeline rule
      return s__(
        'ScanExecutionPolicy|%{rules} every time a pipeline runs that %{scopes} %{branches} using %{sources} %{branchExceptions} %{agents} %{namespaces}',
      );
    },
    showAllPipelineSources() {
      return !TARGET_BRANCHES.includes(this.selectedBranchType);
    },
  },
  methods: {
    setSelectedRule(key) {
      this.selectedRule = this.$options.SCAN_EXECUTION_RULES_LABELS[key];
      this.selectedKey = key;
      this.$emit('select-rule', key);
    },
    handleBranchesToAddChange(branches) {
      /**
       * Either branch of branch_type property
       * is simultaneously allowed on rule object
       * Based on value we remove one and
       * set another and vice versa
       */
      const updatedRule = { ...this.initRule, branches };
      delete updatedRule.branch_type;

      this.$emit('changed', updatedRule);
    },
    handleBranchTypeSelect(branchType) {
      this.selectedBranchType = branchType;

      const updatedRule = handleBranchTypeSelect({
        branchType,
        rule: this.initRule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      this.$emit('changed', updatedRule);
    },
    removeProperty(property) {
      const rule = { ...this.initRule };
      if (property in rule) {
        delete rule[property];
      }

      this.$emit('changed', rule);
    },
    updateRule(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
  },
};
</script>

<template>
  <div
    class="security-policies-bg-subtle gl-relative gl-flex gl-gap-3 gl-rounded-base gl-p-5 gl-pr-0 gl-pt-0"
  >
    <div class="gl-mt-5 gl-grow gl-bg-default gl-pb-5 gl-pl-5 gl-pt-5">
      <div class="gl-flex gl-w-full gl-flex-wrap gl-items-center gl-gap-3">
        <gl-sprintf :message="message">
          <template v-if="glSlots().period" #period>
            <slot name="period"></slot>
          </template>

          <template v-if="glSlots().scopes" #scopes>
            <slot name="scopes"></slot>
          </template>

          <template #rules>
            <gl-collapsible-listbox
              data-testid="rule-component-type"
              :items="rulesListBoxItems"
              :selected="selectedKey"
              :toggle-text="selectedRule"
              @select="setSelectedRule"
            />
          </template>

          <template #branches>
            <template v-if="isBranchScope">
              <branch-type-selector
                :branches-to-add="branchesToAdd"
                :branch-types="branchTypes"
                :selected-branch-type="selectedBranchType"
                @input="handleBranchesToAddChange"
                @set-branch-type="handleBranchTypeSelect"
              />
              <span data-testid="rule-branches-label"> {{ branchesLabel }} </span>
            </template>
          </template>

          <template #sources>
            <pipeline-source-selector
              :show-all-sources="showAllPipelineSources"
              :pipeline-sources="pipelineSources"
              @remove="removeProperty($options.PIPELINE_SOURCES_KEY)"
              @select="updateRule"
            />
          </template>

          <template #branchExceptions>
            <branch-exception-selector
              :selected-exceptions="branchExceptions"
              @remove="removeProperty($options.BRANCH_EXCEPTIONS_KEY)"
              @select="updateRule"
            />
          </template>

          <template v-if="glSlots().agents" #agents>
            <slot name="agents"></slot>
          </template>

          <template v-if="glSlots().namespaces" #namespaces>
            <slot name="namespaces"></slot>
          </template>
        </gl-sprintf>
      </div>
    </div>

    <div class="gl-min-w-7 gl-shrink-0 gl-pr-3 gl-pt-3">
      <gl-button
        icon="remove"
        category="tertiary"
        :aria-label="__('Remove')"
        data-testid="remove-rule"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>
