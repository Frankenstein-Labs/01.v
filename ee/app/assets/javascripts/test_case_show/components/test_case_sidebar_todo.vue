<script>
import { GlTooltipDirective as GlTooltip, GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { __ } from '~/locale';
import { TYPE_TEST_CASE } from '~/issues/constants';
import TestCaseGraphQL from '../mixins/test_case_graphql';

export default {
  name: 'TestCaseSidebarTodo',
  TYPE_TEST_CASE,
  components: {
    GlButton,
    GlIcon,
    GlLoadingIcon,
  },
  directives: {
    GlTooltip,
  },
  mixins: [TestCaseGraphQL],
  inject: ['projectFullPath', 'testCaseId', 'canEditTestCase'],
  props: {
    sidebarExpanded: {
      type: Boolean,
      required: true,
    },
    todo: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isTodoPending() {
      return this.todo?.state === 'pending';
    },
    todoUpdateInProgress() {
      return this.$apollo.queries.testCase.loading || this.testCaseTodoUpdateInProgress;
    },
    todoActionText() {
      return this.isTodoPending ? __('Mark as done') : __('Add a to-do item');
    },
    todoIcon() {
      return this.isTodoPending ? 'todo-done' : 'todo-add';
    },
  },
  methods: {
    handleTodoButtonClick() {
      if (this.isTodoPending) {
        this.markTestCaseTodoDone();
      } else {
        this.addTestCaseAsTodo();
      }
    },
  },
};
</script>

<template>
  <div v-if="canEditTestCase" class="-gl-order-1">
    <div v-if="sidebarExpanded" data-testid="todo" class="todo gl-flex">
      <gl-button
        :loading="todoUpdateInProgress"
        size="small"
        data-testid="expanded-button"
        @click="handleTodoButtonClick"
        >{{ todoActionText }}</gl-button
      >
    </div>
    <div v-else class="block todo">
      <gl-button
        v-gl-tooltip:body.viewport.left
        :title="todoActionText"
        class="sidebar-collapsed-icon"
        category="tertiary"
        data-testid="collapsed-button"
        @click="handleTodoButtonClick"
      >
        <gl-loading-icon v-if="todoUpdateInProgress" size="sm" />
        <gl-icon v-else :name="todoIcon" :class="{ 'todo-undone': isTodoPending }" />
      </gl-button>
    </div>
  </div>
</template>
