<script>
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import { buildWorkPlanChatCommand } from './constants';

export default {
  name: 'GenerateWorkplanEmptyState',
  components: {
    DuoChatQuickAction,
  },
  props: {
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
  emits: ['generate-workplan'],
  computed: {
    command() {
      return buildWorkPlanChatCommand(this.workItemWebUrl);
    },
  },
  tracking: { label: 'create_work_plan' },
  buttonOptions: { variant: 'confirm', icon: '' },
};
</script>

<template>
  <div>
    <h2 class="gl-heading-2 gl-mb-0" data-testid="workplan-header">
      {{ s__('DuoAgenticChat|Ready when you are') }}
    </h2>
    <p class="gl-text-subtle" data-testid="workplan-description">
      {{
        s__(
          'DuoAgenticChat|Work with GitLab Duo to break your item into an efficient implementation plan.',
        )
      }}
    </p>
    <div>
      <duo-chat-quick-action
        :resource-id="resourceId"
        :button-text="s__('DuoAgenticChat|Generate workplan')"
        :command="command"
        :tracking-info="$options.tracking"
        :button-options="$options.buttonOptions"
        data-testid="generate-workplan-button"
        @chat-opened="$emit('generate-workplan')"
      />
    </div>
  </div>
</template>
