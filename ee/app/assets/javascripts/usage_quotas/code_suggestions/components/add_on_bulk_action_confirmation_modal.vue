<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import { ASSIGN_SEATS_BULK_ACTION } from 'ee/usage_quotas/code_suggestions/constants';

export default {
  name: 'AddOnBulkActionConfirmationModal',
  components: {
    GlButton,
    GlModal,
  },
  props: {
    userCount: {
      type: Number,
      required: true,
    },
    bulkAction: {
      type: String,
      required: true,
    },
    isBulkActionInProgress: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel', 'confirm-seat-assignment', 'confirm-seat-unassignment'],
  computed: {
    isBulkActionToAssignSeats() {
      return this.bulkAction === ASSIGN_SEATS_BULK_ACTION;
    },
    confirmationText() {
      return s__('Billing|Are you sure you want to continue?');
    },
    modalTitle() {
      if (this.isBulkActionToAssignSeats) {
        return s__('Billing|Confirm bulk seat assignment');
      }
      return s__('Billing|Confirm bulk seat removal');
    },
    modalBodyText() {
      let actionText;

      if (this.isBulkActionToAssignSeats) {
        actionText = n__(
          'Billing|This action will assign a GitLab Duo seat to 1 user',
          'Billing|This action will assign a GitLab Duo seat to %d users',
          this.userCount,
        );
      } else {
        actionText = n__(
          'Billing|This action will remove GitLab Duo seat from 1 user',
          'Billing|This action will remove GitLab Duo seats from %d users',
          this.userCount,
        );
      }

      return `${actionText}. ${this.confirmationText}`;
    },
  },
  methods: {
    hide() {
      this.$emit('cancel');
    },
    confirmSeatAssignment() {
      this.$emit('confirm-seat-assignment');
    },
    confirmSeatUnassignment() {
      this.$emit('confirm-seat-unassignment');
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="add-on-bulk-action-confirmation-modal"
    :title="modalTitle"
    :visible="true"
    size="sm"
    @hide="hide"
  >
    <p data-testid="bulk-action-confirmation-modal-body">{{ modalBodyText }}</p>

    <template #modal-footer>
      <div class="gl-m-0 gl-flex gl-flex-row gl-flex-wrap gl-justify-end">
        <gl-button
          data-testid="bulk-action-cancel-button"
          :disabled="isBulkActionInProgress"
          @click="hide"
        >
          {{ __('Cancel') }}
        </gl-button>
        <gl-button
          v-if="isBulkActionToAssignSeats"
          variant="confirm"
          data-testid="assign-confirmation-button"
          :loading="isBulkActionInProgress"
          @click="confirmSeatAssignment"
        >
          {{ s__('Billing|Assign seats') }}
        </gl-button>
        <gl-button
          v-else
          variant="danger"
          data-testid="unassign-confirmation-button"
          :loading="isBulkActionInProgress"
          @click="confirmSeatUnassignment"
        >
          {{ s__('Billing|Remove seats') }}
        </gl-button>
      </div>
    </template>
  </gl-modal>
</template>
