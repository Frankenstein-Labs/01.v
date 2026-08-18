<script>
export default {
  name: 'AgentDataLabel',
  props: {
    label: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div class="label-value-container gl-flex gl-flex-row gl-justify-between">
    <div class="gl-py-2 gl-pr-3 gl-font-bold">{{ label }}</div>
    <div class="gl-flex gl-items-center gl-justify-end">
      <slot></slot>
    </div>
  </div>
</template>
