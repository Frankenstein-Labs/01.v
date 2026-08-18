<script>
import { GlCard, GlFormCheckbox } from '@gitlab/ui';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import { SCAN_EXECUTION_SCANNERS } from '../constants';

export default {
  name: 'OptimizedScanSelection',
  components: {
    GlCard,
    GlFormCheckbox,
  },
  props: {
    actions: {
      type: Array,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  computed: {
    optimizedScanners() {
      //  DAST scans are too complex for the optimized path
      const { [REPORT_TYPE_DAST]: dastOption, ...availableScanners } = SCAN_EXECUTION_SCANNERS;
      return Object.entries(availableScanners);
    },
    selectedScanners() {
      return this.actions.map((action) => action.scan);
    },
  },
  methods: {
    isDisabled(scanner) {
      return !this.isSelected(scanner) && this.disabled;
    },
    isSelected(scanner) {
      return this.selectedScanners.includes(scanner);
    },
    onScannerChange(scanner, enabled) {
      this.$emit('change', { enabled, scanner });
    },
  },
};
</script>

<template>
  <div class="optimized-scan-selection">
    <h5>{{ s__('SecurityOrchestration|Security scans to execute') }}</h5>
    <gl-card class="gl-mb-5 gl-bg-default">
      <gl-form-checkbox
        v-for="[key, value] in optimizedScanners"
        :id="key"
        :key="key"
        :data-testid="`${key}-checkbox`"
        :disabled="isDisabled(key)"
        :checked="isSelected(key)"
        @change="onScannerChange(key, $event)"
      >
        {{ value }}
      </gl-form-checkbox>
    </gl-card>
  </div>
</template>
