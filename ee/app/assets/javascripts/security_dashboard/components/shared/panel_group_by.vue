<script>
import { GlButton, GlButtonGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

const buttons = {
  severity: {
    label: s__('SecurityReports|Severity'),
    value: 'severity',
  },
  reportType: {
    label: s__('SecurityReports|Report Type'),
    value: 'reportType',
  },
};

export default {
  name: 'PanelGroupBy',
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
  buttons,
  emits: ['input'],
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
