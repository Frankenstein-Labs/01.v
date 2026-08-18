<script>
import { parseToolInfo } from 'ee/ai/duo_agents_platform/icon_utils';
import TodoChecklist from './todo_checklist.vue';

export default {
  name: 'MessageTodoChecklist',
  components: {
    TodoChecklist,
  },
  props: {
    message: {
      required: true,
      type: Object,
    },
  },
  computed: {
    toolInfo() {
      return parseToolInfo(this.message?.tool_info);
    },
    flowFinished() {
      return Boolean(this.message?.todoFinished);
    },
  },
};
</script>
<template>
  <todo-checklist v-if="toolInfo" :tool-info="toolInfo" :flow-finished="flowFinished" />
</template>
