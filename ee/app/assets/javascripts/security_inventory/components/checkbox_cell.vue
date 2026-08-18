<script>
import { GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'CheckboxCell',
  components: {
    GlFormCheckbox,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    isSelected: {
      type: Boolean,
      required: true,
    },
    isSelectedLimitReached: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['select-item'],
  computed: {
    disabled() {
      return this.isSelectedLimitReached && !this.isSelected;
    },
  },
  methods: {
    handleChange(checked) {
      this.$emit('select-item', this.item, checked);
    },
  },
};
</script>
<template>
  <gl-form-checkbox
    :checked="isSelected"
    :disabled="disabled"
    class="gl-inline"
    @change="handleChange"
  >
    <span class="gl-sr-only">{{ __('Select item') }}</span>
  </gl-form-checkbox>
</template>
