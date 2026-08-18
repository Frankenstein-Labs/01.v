<script>
import AiToolRulesTable from './ai_tool_rules_table.vue';

export default {
  name: 'AiToolManagementApp',
  components: {
    AiToolRulesTable,
  },
};
</script>

<template>
  <div>
    <ai-tool-rules-table class="gl-mt-5" />
  </div>
</template>
