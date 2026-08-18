<script>
import WebhookFormTriggerItem from '~/webhooks/components/webhook_form_trigger_item.vue';
import { EE_TRIGGER_CONFIG } from '../constants';

export default {
  name: 'GroupEventsTriggerItems',
  components: {
    WebhookFormTriggerItem,
  },
  props: {
    initialMemberTrigger: {
      type: Boolean,
      required: true,
    },
    initialProjectTrigger: {
      type: Boolean,
      required: true,
    },
    initialSubgroupTrigger: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      memberEvents: this.initialMemberTrigger,
      projectEvents: this.initialProjectTrigger,
      subgroupEvents: this.initialSubgroupTrigger,
      memberConfig: EE_TRIGGER_CONFIG.member,
      projectConfig: EE_TRIGGER_CONFIG.project,
      subgroupConfig: EE_TRIGGER_CONFIG.subgroup,
    };
  },
};
</script>

<template>
  <div data-testid="groupEventsTriggers">
    <webhook-form-trigger-item
      v-model="memberEvents"
      :data-testid="memberConfig.key"
      :input-name="memberConfig.inputName"
      :trigger-name="memberConfig.key"
      :label="memberConfig.label"
      :help-text="memberConfig.helpText"
    />

    <webhook-form-trigger-item
      v-model="projectEvents"
      :data-testid="projectConfig.key"
      :input-name="projectConfig.inputName"
      :trigger-name="projectConfig.key"
      :label="projectConfig.label"
      :help-text="projectConfig.helpText"
    />

    <webhook-form-trigger-item
      v-model="subgroupEvents"
      :data-testid="subgroupConfig.key"
      :input-name="subgroupConfig.inputName"
      :trigger-name="subgroupConfig.key"
      :label="subgroupConfig.label"
      :help-text="subgroupConfig.helpText"
    />
  </div>
</template>
