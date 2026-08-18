<script>
import { GlButton, GlButtonGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

const buttons = {
  default: {
    label: s__('SecurityReports|No grouping'),
    value: 'default',
  },
  project: {
    label: s__('SecurityReports|Project'),
    value: 'project',
  },
};

export default {
  components: {
    GlButton,
    GlButtonGroup,
  },
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => Object.values(buttons).some((button) => button.value === value),
    },
  },
  emits: ['input'],
  buttons,
};
</script>

<template>
  <gl-button-group>
    <gl-button
      v-for="button in $options.buttons"
      :key="button.value"
      :data-testid="`${button.value}-button`"
      size="small"
      category="secondary"
      :selected="value === button.value"
      @click="$emit('input', button.value)"
    >
      {{ button.label }}
    </gl-button>
  </gl-button-group>
</template>
