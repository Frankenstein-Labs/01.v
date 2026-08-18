<script>
import { eventHub, OPEN_AGENT_PLAN_PANEL } from 'ee/ai/events/panel';
import ReviewWorkplanEmptyState from './review_workplan_empty_state.vue';
import GenerateWorkplanEmptyState from './generate_workplan_empty_state.vue';

export default {
  name: 'WorkplanEmptyStateHeader',
  components: {
    ReviewWorkplanEmptyState,
    GenerateWorkplanEmptyState,
  },
  props: {
    hasExistingWorkplan: {
      type: Boolean,
      required: false,
      default: false,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    workItemWebUrl: {
      type: String,
      required: true,
    },
  },
  methods: {
    onViewWorkplan() {
      eventHub.$emit(OPEN_AGENT_PLAN_PANEL);
    },
  },
};
</script>

<template>
  <review-workplan-empty-state v-if="hasExistingWorkplan" @review-workplan="onViewWorkplan" />
  <generate-workplan-empty-state
    v-else
    :resource-id="resourceId"
    :work-item-web-url="workItemWebUrl"
    @generate-workplan="onViewWorkplan"
  />
</template>
