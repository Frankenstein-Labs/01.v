<script>
import { GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { TODO_STATUS_ICON } from 'ee/ai/duo_agents_platform/constants';

export default {
  name: 'TodoChecklist',
  components: {
    GlIcon,
    GlLoadingIcon,
  },
  props: {
    toolInfo: {
      type: Object,
      required: true,
    },
    bordered: {
      type: Boolean,
      required: false,
      default: true,
    },
    flowFinished: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    todos() {
      return this.toolInfo?.args?.todos || [];
    },
    containerClasses() {
      return this.bordered ? 'gl-border gl-rounded-base gl-px-4 gl-py-3' : '';
    },
  },
  methods: {
    statusIcon(status) {
      return TODO_STATUS_ICON[status] ?? TODO_STATUS_ICON.pending;
    },
    isInProgress(status) {
      return status === 'in_progress';
    },
  },
};
</script>
<template>
  <div v-if="todos.length" data-testid="todo-checklist-container" :class="containerClasses">
    <ul class="gl-m-0 gl-list-none gl-pl-0">
      <li
        v-for="(todo, index) in todos"
        :key="index"
        class="gl-flex gl-items-start gl-gap-3 gl-py-1"
      >
        <gl-loading-icon
          v-if="!flowFinished && isInProgress(todo.status)"
          size="sm"
          class="gl-mt-2 gl-shrink-0"
        />
        <gl-icon v-else v-bind="statusIcon(todo.status)" :size="16" class="gl-mt-2 gl-shrink-0" />
        <span>{{ todo.description }}</span>
      </li>
    </ul>
  </div>
</template>
