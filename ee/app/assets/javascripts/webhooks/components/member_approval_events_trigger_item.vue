<script>
import WebhookFormTriggerItem from '~/webhooks/components/webhook_form_trigger_item.vue';
import { EE_TRIGGER_CONFIG } from '../constants';

export default {
  name: 'MemberApprovalEventsTriggerItem',
  components: {
    WebhookFormTriggerItem,
  },
  props: {
    initialMemberApprovalTrigger: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      memberApprovalEvents: this.initialMemberApprovalTrigger,
    };
  },
  config: EE_TRIGGER_CONFIG.memberApproval,
};
</script>

<template>
  <div>
    <webhook-form-trigger-item
      v-model="memberApprovalEvents"
      :data-testid="$options.config.key"
      :input-name="$options.config.inputName"
      :trigger-name="$options.config.key"
      :label="$options.config.label"
      :help-text="$options.config.helpText"
    />
  </div>
</template>
