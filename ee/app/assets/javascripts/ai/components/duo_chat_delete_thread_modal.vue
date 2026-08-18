<script>
import { GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  name: 'DuoChatDeleteThreadModal',
  components: {
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
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['confirm', 'change'],
  computed: {
    primaryAction() {
      return {
        text: __('Delete'),
        attributes: { variant: 'danger', loading: this.loading },
      };
    },
    cancelAction() {
      return {
        text: __('Cancel'),
        attributes: { disabled: this.loading },
      };
    },
  },
  methods: {
    onPrimary(event) {
      // Keep the modal open with a spinner on the Delete button until the
      // parent resolves the deletion request, then it closes the modal.
      event.preventDefault();
      this.$emit('confirm');
    },
  },
  i18n: {
    title: s__('DuoChat|Delete chat'),
    body: s__('DuoChat|Are you sure you want to delete this chat?'),
  },
  modalId: 'duo-chat-delete-thread-modal',
};
</script>

<template>
  <gl-modal
    :modal-id="$options.modalId"
    :visible="visible"
    :title="$options.i18n.title"
    size="sm"
    :action-primary="primaryAction"
    :action-cancel="cancelAction"
    :no-close-on-backdrop="loading"
    :no-close-on-esc="loading"
    @primary="onPrimary"
    @change="$emit('change', $event)"
  >
    {{ $options.i18n.body }}
  </gl-modal>
</template>
