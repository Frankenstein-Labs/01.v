<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';

const TIME_PERIOD_OPTIONS = [
  {
    value: 30,
    text: s__('SecurityReports|30 days'),
  },
  {
    value: 60,
    text: s__('SecurityReports|60 days'),
  },
  {
    value: 90,
    text: s__('SecurityReports|90 days'),
  },
];

export default {
  name: 'OverTimePeriodSelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    value: {
      type: Number,
      required: false,
      default: 30,
    },
  },
  emits: ['input'],
  data() {
    return {
      selected: this.value,
    };
  },
  computed: {
    selectedOption() {
      return TIME_PERIOD_OPTIONS.find((option) => option.value === this.selected);
    },
    toggleText() {
      return this.selectedOption?.text || TIME_PERIOD_OPTIONS[0].text;
    },
  },
  timePeriodOptions: TIME_PERIOD_OPTIONS,
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="selected"
    :items="$options.timePeriodOptions"
    :toggle-text="toggleText"
    :header-text="s__('SecurityReports|Time period')"
    size="small"
    data-testid="time-period-selector"
    class="gl-w-full"
    @select="$emit('input', $event)"
  />
</template>
