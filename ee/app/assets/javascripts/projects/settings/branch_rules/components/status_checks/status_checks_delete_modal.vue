<script>
import { GlModal, GlModalDirective, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';

const i18n = {
  cancelButton: __('Cancel'),
  primaryButton: s__('BranchRules|Delete status check'),
  title: s__('BranchRules|Delete status check?'),
  warningText: s__('BranchRules|You are about to delete the %{name} status check.'),
};

export default {
  name: 'StatusChecksDeleteModal',
  components: {
    GlModal,
    GlSprintf,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedStatusCheck: {
      type: Object,
      required: false,
      default: () => null,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close-modal', 'delete-status-check'],
  computed: {
    primaryActionProps() {
      return {
        text: i18n.primaryButton,
        attributes: { variant: 'danger', loading: this.isLoading },
      };
    },
  },
  cancelActionProps: {
    text: i18n.cancelButton,
  },
  i18n,
};
</script>

<template>
  <gl-modal
    :visible="isOpen"
    modal-id="statusChecksDeleteModal"
    :title="$options.i18n.title"
    :action-primary="primaryActionProps"
    :action-cancel="$options.cancelActionProps"
    size="sm"
    @ok.prevent="$emit('delete-status-check', selectedStatusCheck.id)"
    @change="$emit('close-modal')"
  >
    <div
      v-if="selectedStatusCheck"
      class="gl-inline-flex gl-w-full gl-min-w-0 gl-flex-wrap gl-gap-2"
    >
      <gl-sprintf :message="$options.i18n.warningText">
        <template #name>
          <span class="gl-truncate gl-font-bold">{{ selectedStatusCheck.name }}</span>
        </template>
      </gl-sprintf>
    </div>
  </gl-modal>
</template>
