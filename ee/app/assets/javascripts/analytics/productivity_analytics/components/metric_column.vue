<script>
import { n__ } from '~/locale';

export default {
  name: 'MetricColumn',
  props: {
    type: {
      type: String,
      required: true,
    },
    /**
     * With default null we will render a "-" in the last column as opposed to a numeric value
     */
    value: {
      type: Number,
      required: false,
      default: null,
    },
    label: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    isNumber() {
      return typeof this.value === 'number';
    },
    unit() {
      return this.type === 'days_to_merge'
        ? n__('day', 'days', this.value)
        : n__('Time|hr', 'Time|hrs', this.value);
    },
  },
};
</script>
<template>
  <div class="gl-max-w-1/2 gl-shrink-0 gl-grow-0 gl-basis-1/2">
    <span class="time gl-text-lg">
      <template v-if="isNumber">
        {{ value }}
        <span class="gl-text-base"> {{ unit }} </span>
      </template>
      <template v-else> &ndash; </template>
    </span>
    <span v-if="label" class="gl-flex gl-whitespace-pre-wrap gl-text-subtle @md/panel:gl-hidden">{{
      label
    }}</span>
  </div>
</template>
