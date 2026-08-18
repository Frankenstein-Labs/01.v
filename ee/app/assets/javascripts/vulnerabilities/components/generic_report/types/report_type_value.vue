<script>
export default {
  name: 'ReportTypeValue',
  inheritAttrs: false,
  props: {
    value: {
      type: [String, Number, Boolean],
      required: true,
    },
  },
};
</script>
<template>
  <span>{{ value }}</span>
</template>
