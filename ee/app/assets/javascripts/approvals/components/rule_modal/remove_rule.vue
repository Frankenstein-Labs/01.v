<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { n__, __ } from '~/locale';

const i18n = {
  cancelButtonText: __('Cancel'),
  primaryButtonText: __('Remove approvers'),
  modalTitle: __('Remove approvers?'),
  removeWarningText: (i) =>
    n__(
      'ApprovalRuleRemove|You are about to remove the %{name} approver group which has %{strongStart}%{count} member%{strongEnd}. Approvals from this member are not revoked.',
      'ApprovalRuleRemove|You are about to remove the %{name} approver group which has %{strongStart}%{count} members%{strongEnd}. Approvals from these members are not revoked.',
      i,
    ),
};

export default {
  name: 'RemoveRule',
  components: {
    GlModal,
    GlSprintf,
  },
  props: {
    modalId: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState('deleteModal', {
      rule: 'data',
      isVisible: 'isVisible',
    }),
    approversCount() {
      return this.rule.eligibleApprovers.length;
    },
    modalText() {
      return i18n.removeWarningText(this.approversCount);
    },
    primaryButtonProps() {
      return {
        text: i18n.primaryButtonText,
        attributes: { variant: 'danger' },
      };
    },
  },
  methods: {
    ...mapActions(['deleteRule']),
    ...mapActions({
      modalHide(dispatch) {
        return dispatch(`deleteModal/hide`);
      },
    }),
    submit() {
      this.deleteRule(this.rule.id);
    },
    handleModalChange(shouldShowModal) {
      if (!shouldShowModal) {
        this.modalHide();
      }
    },
  },
  cancelButtonProps: {
    text: i18n.cancelButtonText,
  },
  i18n,
};
</script>

<template>
  <gl-modal
    :visible="isVisible"
    :modal-id="modalId"
    :title="$options.i18n.modalTitle"
    :action-primary="primaryButtonProps"
    :action-cancel="$options.cancelButtonProps"
    @change="handleModalChange"
    @ok.prevent="submit"
  >
    <p v-if="rule">
      <gl-sprintf :message="modalText">
        <template #name>
          <strong>{{ rule.name }}</strong>
        </template>
        <template #strong="{ content }">
          <strong>
            <gl-sprintf :message="content">
              <template #count>{{ approversCount }}</template>
            </gl-sprintf>
          </strong>
        </template>
      </gl-sprintf>
    </p>
  </gl-modal>
</template>
