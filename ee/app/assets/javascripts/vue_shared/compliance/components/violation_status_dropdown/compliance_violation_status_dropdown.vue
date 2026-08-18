<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { COMPLIANCE_STATUS_OPTIONS } from '../../constants';

export default {
  name: 'ComplianceViolationStatusDropdown',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => COMPLIANCE_STATUS_OPTIONS.some((option) => option.value === value),
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      statusOptions: COMPLIANCE_STATUS_OPTIONS,
    };
  },
  computed: {
    selectedOption() {
      return this.statusOptions.find((option) => option.value === this.value);
    },
    toggleText() {
      return this.selectedOption?.text || '';
    },
  },
  methods: {
    handleSelect(selectedValue) {
      if (selectedValue !== this.value) {
        this.$emit('change', selectedValue);
      }
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="statusOptions"
    :selected="value"
    :toggle-text="toggleText"
    :disabled="disabled"
    :loading="loading"
    variant="link"
    @select="handleSelect"
  />
</template>
