<script>
import { s__ } from '~/locale';
import BaseSeverityStatusScanner from './base_severity_status_scanner.vue';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Coverage Fuzzing Scanning Rule'),
  },
  name: 'CoverageFuzzingScanner',
  components: {
    BaseSeverityStatusScanner,
  },
  props: {
    scanner: {
      type: Object,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['changed', 'remove'],
  methods: {
    handleChanged(value) {
      this.$emit('changed', value);
    },
  },
};
</script>

<template>
  <base-severity-status-scanner
    :scanner="scanner"
    :visible="visible"
    :title="$options.i18n.title"
    @changed="handleChanged"
    @remove="$emit('remove')"
  />
</template>
