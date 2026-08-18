<script>
import { GlAlert, GlButton, GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  WARN_MODE,
  EXCEPTION_MODE,
  INITIAL_STATE_NEXT_STEPS,
} from 'ee/vue_merge_request_widget/components/checks/constants';

export default {
  INITIAL_STATE_NEXT_STEPS,
  SELECTOR_ITEMS: [
    {
      header: s__('SecurityOrchestration|Exception Bypass (pre-approved)'),
      description: s__(
        'SecurityOrchestration|You have been granted bypass permissions for these policies based on organizational role or custom role assignments.',
      ),
      key: EXCEPTION_MODE,
    },
    {
      header: s__('SecurityOrchestration|Warn mode (bypass eligible)'),
      description: s__(
        'SecurityOrchestration|These policies are configured in warn mode. This allows you to bypass violations with proper justification.',
      ),
      key: WARN_MODE,
    },
  ],
  name: 'SecurityPolicyViolationsSelector',
  components: {
    GlAlert,
    GlButton,
    GlModal,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close', 'select'],
  methods: {
    handleClose() {
      this.$emit('close');
    },
    handleChange(opened) {
      if (!opened) {
        this.handleClose();
      }
    },
    selectKey(key) {
      this.$emit('select', key);
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="security-policy-violations-modal"
    hide-footer
    :title="s__('SecurityOrchestration|Bypass Policy Violation')"
    size="md"
    @cancel="handleClose"
    @change="handleChange"
  >
    <gl-alert variant="info" :dismissible="false" class="gl-mb-4" :title="__('What happens next?')">
      <ul class="gl-mb-0 gl-pl-5">
        <li v-for="step in $options.INITIAL_STATE_NEXT_STEPS" :key="step">
          {{ step }}
        </li>
      </ul>
    </gl-alert>

    <div v-for="item in $options.SELECTOR_ITEMS" :key="item.key" class="gl-my-7">
      <h5 data-testid="header">{{ item.header }}</h5>
      <div class="gl-flex gl-items-start">
        <p data-testid="description" class="gl-m-0 gl-pr-12">{{ item.description }}</p>
        <div>
          <gl-button category="primary" variant="confirm" @click="selectKey(item.key)">{{
            __('Continue')
          }}</gl-button>
        </div>
      </div>
    </div>
  </gl-modal>
</template>
