<script>
import { GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  name: 'DeleteSubscriptionConfirmationModal',
  i18n: {
    title: s__('PipelineSubscriptions|Delete subscription'),
    description: s__(
      'PipelineSubscriptions|Subscription for this project will be removed. Do you want to continue?',
    ),
  },
  modal: {
    id: 'delete-subscription-modal',
    actionPrimary: {
      text: __('OK'),
      attributes: {
        variant: 'danger',
      },
    },
    actionCancel: {
      text: __('Cancel'),
      attributes: {
        variant: 'default',
      },
    },
  },
  components: {
    GlModal,
  },
  props: {
    isModalVisible: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['delete-confirmed', 'hide'],
};
</script>

<template>
  <gl-modal
    :modal-id="$options.modal.id"
    :title="$options.i18n.title"
    :action-primary="$options.modal.actionPrimary"
    :action-cancel="$options.modal.actionCancel"
    :visible="isModalVisible"
    size="sm"
    @primary="$emit('delete-confirmed')"
    @hidden="$emit('hide')"
  >
    <p>{{ $options.i18n.description }}</p>
  </gl-modal>
</template>
