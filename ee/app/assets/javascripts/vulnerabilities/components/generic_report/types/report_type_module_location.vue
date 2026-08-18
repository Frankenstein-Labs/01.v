<script>
export default {
  name: 'ReportTypeModuleLocation',
  inheritAttrs: false,
  props: {
    moduleName: {
      type: String,
      required: true,
    },
    offset: {
      type: Number,
      required: true,
    },
  },
};
</script>
<template>
  <span>{{ moduleName }}:{{ offset }}</span>
</template>
