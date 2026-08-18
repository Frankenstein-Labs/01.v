<script>
import { GlFormGroup, GlFormInput, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  name: 'ApprovalsAuth',
  components: {
    GlFormGroup,
    GlFormInput,
    GlModal,
  },
  props: {
    isApproving: {
      type: Boolean,
      default: false,
      required: false,
    },
    hasError: {
      type: Boolean,
      default: false,
      required: false,
    },
    modalId: {
      type: String,
      required: true,
    },
  },
  emits: ['approve', 'hide'],
  data() {
    return {
      approvalPassword: '',
    };
  },
  computed: {
    actionPrimaryProps() {
      return {
        text: __('Approve'),
        attributes: {
          loading: this.isApproving,
          variant: 'confirm',
        },
      };
    },
    actionCancelProps() {
      return {
        text: __('Cancel'),
      };
    },
    inputState() {
      return this.hasError ? false : null;
    },
    invalidFeedback() {
      return this.hasError ? s__('mrWidget|Approval password is invalid.') : null;
    },
  },
  methods: {
    approve(event) {
      event.preventDefault();
      this.$emit('approve', this.approvalPassword);
    },
    onHide() {
      this.approvalPassword = '';
      this.$emit('hide');
    },
    onShow() {
      setTimeout(() => {
        this.$refs.approvalPasswordInput.$el.focus();
      }, 0);
    },
  },
};
</script>

<template>
  <gl-modal
    :modal-id="modalId"
    :title="__('Enter your password to approve')"
    :action-primary="actionPrimaryProps"
    :action-cancel="actionCancelProps"
    modal-class="js-mr-approvals-modal"
    @ok="approve"
    @hide="onHide"
    @show="onShow"
  >
    <form @submit.prevent="approve">
      <p>
        {{
          s__(
            'mrWidget|To approve this merge request, please enter your password. This project requires all approvals to be authenticated.',
          )
        }}
      </p>
      <gl-form-group
        :label="s__('mrWidget|Your password')"
        label-for="approvalPasswordInput"
        :invalid-feedback="invalidFeedback"
        class="gl-mb-0"
      >
        <gl-form-input
          id="approvalPasswordInput"
          ref="approvalPasswordInput"
          v-model="approvalPassword"
          type="password"
          autocomplete="current-password"
          :placeholder="__('Password')"
          :state="inputState"
        />
      </gl-form-group>
    </form>
  </gl-modal>
</template>
