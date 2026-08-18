<script>
export default {
  name: 'ExclusionDetail',
  props: {
    label: {
      type: String,
      required: true,
    },
    value: {
      type: [String, Object],
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div class="detail">
    <label>{{ label }}</label>
    <div>{{ value }} <slot></slot></div>
  </div>
</template>
