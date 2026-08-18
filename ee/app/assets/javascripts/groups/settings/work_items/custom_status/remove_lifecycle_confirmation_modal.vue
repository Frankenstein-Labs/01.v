<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'RemoveLifecycleConfirmationModal',
  components: {
    GlButton,
    GlModal,
  },
  props: {
    isVisible: {
      type: Boolean,
      required: true,
    },
    lifecycleName: {
      type: String,
      required: true,
    },
  },
  emits: ['cancel', 'continue'],
  computed: {
    cancelConfirmationText() {
      return s__(
        'WorkItem|Are you sure you want to remove this lifecycle? This action cannot be undone.',
      );
    },
    removeLifecycleConfirmationTitle() {
      return sprintf(s__('WorkItem|Remove lifecycle: "%{lifecycleName}"'), {
        lifecycleName: this.lifecycleName,
      });
    },
  },
  methods: {
    handleCancelConfirmationAction(decision) {
      if (decision === 'continue') {
        this.$emit('continue');
      } else {
        this.$emit('cancel');
      }
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="remove-lifecycle-confirmation"
    :aria-label="s__('WorkItem|Delete Lifecycle Confirmation')"
    :visible="isVisible"
    :scrollable="false"
    :title="removeLifecycleConfirmationTitle"
    no-close-on-esc
    no-close-on-backdrop
    @hide="$emit('cancel')"
  >
    <p class="gl-mb-0 gl-mt-4">{{ cancelConfirmationText }}</p>

    <template #modal-footer>
      <gl-button
        type="button"
        data-testid="remove-lifecycle-cancel"
        @click="handleCancelConfirmationAction('cancel')"
        >{{ s__('WorkItem|Cancel') }}</gl-button
      >
      <gl-button
        type="button"
        variant="danger"
        data-testid="remove-lifecycle-continue"
        @click="handleCancelConfirmationAction('continue')"
        >{{ s__('WorkItem|Remove') }}</gl-button
      >
    </template>
  </gl-modal>
</template>
