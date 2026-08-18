<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isCauseOfError } from 'ee/security_orchestration/components/policy_editor/utils';
import { ANY_MERGE_REQUEST, SCAN_FINDING, LICENSE_FINDING } from '../lib';

export default {
  scanTypeOptions: [
    {
      value: ANY_MERGE_REQUEST,
      text: s__('SecurityOrchestration|any merge request'),
    },
    {
      value: SCAN_FINDING,
      text: s__('SecurityOrchestration|security scan'),
    },
    {
      value: LICENSE_FINDING,
      text: s__('SecurityOrchestration|license scan'),
    },
  ],
  i18n: {
    scanRuleTypeToggleText: s__('SecurityOrchestration|select scan type'),
  },
  name: 'ScanTypeSelect',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    index: {
      type: Number,
      required: false,
      default: 0,
    },
    scanType: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['select'],
  computed: {
    isErrorSource() {
      return isCauseOfError({
        errorSources: this.errorSources,
        primaryKey: 'rules',
        index: this.index,
        location: 'type',
      });
    },
    scanRuleTypeToggleText() {
      return this.scanType ? '' : this.$options.i18n.scanRuleTypeToggleText;
    },
  },
  methods: {
    setScanType(value) {
      this.$emit('select', value);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    id="scanType"
    class="!gl-inline gl-w-auto gl-align-middle"
    :state="!isErrorSource"
    :items="$options.scanTypeOptions"
    :selected="scanType"
    :toggle-text="scanRuleTypeToggleText"
    @select="setScanType"
  />
</template>
