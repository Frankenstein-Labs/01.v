<script>
import { GlModal, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'MergeImmediatelyConfirmationDialog',
  components: {
    GlModal,
    GlButton,
    GlSprintf,
    GlLink,
  },
  props: {
    docsUrl: {
      type: String,
      required: true,
    },
  },
  emits: ['merge-immediately'],
  computed: {
    bodyText() {
      return s__(
        "mrWidget|Merging immediately is not recommended because your changes won't be validated by the merge train, and any running merge train pipelines will be restarted. %{docsLinkStart}What are the risks?%{docsLinkEnd}",
      );
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API for programmatic modal display
    show() {
      this.$refs.modal.show();
    },
    cancel() {
      this.hide();
    },
    mergeImmediately() {
      this.$emit('merge-immediately');
      this.hide();
    },
    hide() {
      this.$refs.modal.hide();
    },
    focusCancelButton() {
      this.$refs.cancelButton.$el.focus();
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    modal-id="merge-immediately-confirmation-dialog"
    :title="__('Merge immediately')"
    @shown="focusCancelButton"
  >
    <p>
      <gl-sprintf :message="bodyText">
        <template #docsLink="{ content }">
          <gl-link :href="docsUrl" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <p>{{ __('Are you sure you want to merge immediately?') }}</p>
    <template #modal-footer>
      <gl-button ref="cancelButton" @click="cancel">{{ __('Cancel') }}</gl-button>
      <gl-button
        variant="danger"
        data-testid="merge-immediately-confirmation-button"
        @click="mergeImmediately"
        >{{ __('Merge immediately') }}</gl-button
      >
    </template>
  </gl-modal>
</template>
