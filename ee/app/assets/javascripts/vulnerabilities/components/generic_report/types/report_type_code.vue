<script>
import CodeBlock from '~/vue_shared/components/code_block.vue';

export default {
  name: 'ReportTypeCode',
  components: {
    CodeBlock,
  },
  props: {
    value: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <code-block :code="value" class="!gl-mb-0" />
</template>
