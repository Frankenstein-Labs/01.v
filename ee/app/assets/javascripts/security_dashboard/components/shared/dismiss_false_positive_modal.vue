<script>
import { GlModal } from '@gitlab/ui';
import dismissFalsePositiveFlagMutation from 'ee/security_dashboard/graphql/mutations/vulnerability_dismiss_false_positive_flag.mutation.graphql';
import { s__, __ } from '~/locale';
import { createAlert } from '~/alert';

export default {
  name: 'DismissFalsePositiveModal',
  components: {
    GlModal,
  },
  inject: {
    vulnerabilitiesQuery: {
      default: null,
    },
  },
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
    modalId: {
      type: String,
      required: false,
      default: 'dismiss-fp-confirm-modal',
    },
  },
  emits: ['error', 'success'],
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Public method
    show() {
      this.$refs.modal.show();
    },
    // eslint-disable-next-line vue/no-unused-properties -- Public method
    hide() {
      this.$refs.modal.hide();
    },
    async dismissFlag() {
      try {
        await this.$apollo.mutate({
          mutation: dismissFalsePositiveFlagMutation,
          variables: {
            id: this.vulnerability.id,
          },
          refetchQueries: this.vulnerabilitiesQuery ? [this.vulnerabilitiesQuery] : [],
        });

        this.$emit('success');
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
        this.$emit('error', error);
      }
    },
  },
  i18n: {
    title: s__('Vulnerability|Dismiss False Positive Flag'),
    text: s__(
      "Vulnerability|Removing this flag will not change the vulnerability's status. The vulnerability will remain in its current state but will no longer be marked as a false positive.",
    ),
    errorMessage: s__('Vulnerability|Something went wrong while dismissing the vulnerability.'),
  },
  modal: {
    actionPrimary: {
      text: s__('Vulnerability|Dismiss False Positive Flag'),
      attributes: {
        variant: 'danger',
      },
    },
    actionSecondary: {
      text: __('Cancel'),
      attributes: {
        variant: 'default',
      },
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
    :title="$options.i18n.title"
    :action-primary="$options.modal.actionPrimary"
    :action-secondary="$options.modal.actionSecondary"
    @primary="dismissFlag"
  >
    {{ $options.i18n.text }}
  </gl-modal>
</template>
