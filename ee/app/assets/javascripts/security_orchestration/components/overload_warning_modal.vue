<script>
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    actionPrimary: {
      text: s__('ScanExecutionPolicy|Create merge request'),
    },
    actionSecondary: {
      text: s__('ScanExecutionPolicy|Back to edit policy'),
    },
    title: s__('ScanExecutionPolicy|Potential overload for infrastructure'),
    footerTitle: s__(
      'ScanExecutionPolicy|Are you sure you want to create merge request for this policy?',
    ),
    content: s__(
      'ScanExecutionPolicy|This scan execution policy will generate a large number of pipelines, which can have a significant performance impact. To reduce potential performance issues, consider creating separate policies for smaller subsets of projects.',
    ),
  },
  name: 'OverloadWarningModal',
  components: {
    GlModal,
  },
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel-submit', 'confirm-submit'],
  methods: {
    confirm() {
      this.$emit('confirm-submit');
    },
    cancel() {
      this.$emit('cancel-submit');
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="overload-warning-modal"
    :action-primary="$options.i18n.actionPrimary"
    :action-secondary="$options.i18n.actionSecondary"
    :title="$options.i18n.title"
    :visible="visible"
    @change="cancel"
    @canceled="cancel"
    @secondary="cancel"
    @primary="confirm"
  >
    <p>{{ $options.i18n.content }}</p>
    <p class="gl-font-bold">{{ $options.i18n.footerTitle }}</p>
  </gl-modal>
</template>
