<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AgentFlowCancelationModal',
  components: {
    GlButton,
    GlModal,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['hide', 'confirm'],
  computed: {
    modalTitle() {
      return s__('DuoAgentsPlatform|Cancel session?');
    },
  },
  methods: {
    handleHide() {
      this.$emit('hide');
    },
    handleConfirm() {
      this.$emit('confirm');
    },
  },
};
</script>
<template>
  <gl-modal
    modal-id="cancel-session-confirmation-modal"
    :title="modalTitle"
    :visible="visible"
    size="sm"
    data-testid="cancel-session-confirmation-modal"
    @hide="handleHide"
  >
    <p class="gl-mb-0">
      {{
        s__(
          'DuoAgentsPlatform|Are you sure you want to cancel this session? This action cannot be undone.',
        )
      }}
    </p>

    <template #modal-footer>
      <gl-button data-testid="cancel-session-modal-cancel" @click="handleHide">
        {{ __('Cancel') }}
      </gl-button>
      <gl-button
        variant="danger"
        :loading="loading"
        data-testid="cancel-session-modal-confirm"
        @click="handleConfirm"
      >
        {{ s__('DuoAgentsPlatform|Cancel session') }}
      </gl-button>
    </template>
  </gl-modal>
</template>
