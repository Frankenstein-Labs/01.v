<script>
import { GlSprintf, GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  ANY_COMMIT,
  ANY_UNSIGNED_COMMIT,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  BRANCH_EXCEPTIONS_KEY,
} from '../../constants';
import BranchExceptionSelector from '../../branch_exception_selector.vue';
import SectionLayout from '../../section_layout.vue';
import { getDefaultRule } from '../lib';
import BranchSelection from '../../branch_selection.vue';
import ScanTypeSelect from './scan_type_select.vue';

const COMMIT_LISTBOX_ITEMS = [
  {
    value: ANY_COMMIT,
    text: s__('ScanResultPolicy|any commits'),
  },
  {
    value: ANY_UNSIGNED_COMMIT,
    text: s__('ScanResultPolicy|any unsigned commits'),
  },
];

export default {
  COMMIT_LISTBOX_ITEMS,
  i18n: {
    anyMergeRequestRuleCopy: s__(
      'ScanResultPolicy|On %{scanType} when %{commitType} that targets %{branches} %{branchExceptions}',
    ),
  },
  name: 'AnyMergeRequestRuleBuilder',
  components: {
    BranchExceptionSelector,
    ScanTypeSelect,
    SectionLayout,
    GlCollapsibleListbox,
    GlSprintf,
    BranchSelection,
  },
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed', 'set-scan-type'],
  computed: {
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    selectedCommitType() {
      return this.initRule.commits || ANY_COMMIT;
    },
  },
  methods: {
    setBranchType(value) {
      this.$emit('changed', value);
    },
    setScanType(value) {
      const rule = getDefaultRule(value);
      this.$emit('set-scan-type', rule);
    },
    setCommitType(type) {
      this.triggerChanged({ commits: type });
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
  },
};
</script>

<template>
  <section-layout class="gl-pr-0" :type="initRule.type" :show-remove-button="false">
    <template #content>
      <section-layout class="!gl-bg-default" :type="initRule.type" :show-remove-button="false">
        <template #content>
          <gl-sprintf :message="$options.i18n.anyMergeRequestRuleCopy">
            <template #scanType>
              <scan-type-select :scan-type="initRule.type" @select="setScanType" />
            </template>

            <template #branches>
              <branch-selection
                :init-rule="initRule"
                :branch-types="branchTypes"
                @changed="triggerChanged"
                @set-branch-type="setBranchType"
              />
            </template>

            <template #branchExceptions>
              <branch-exception-selector
                :selected-exceptions="branchExceptions"
                @remove="removeExceptions"
                @select="triggerChanged"
              />
            </template>

            <template #commitType>
              <gl-collapsible-listbox
                data-testid="commits-type"
                :items="$options.COMMIT_LISTBOX_ITEMS"
                :selected="selectedCommitType"
                @select="setCommitType"
              />
            </template>
          </gl-sprintf>
        </template>
      </section-layout>
    </template>
  </section-layout>
</template>
