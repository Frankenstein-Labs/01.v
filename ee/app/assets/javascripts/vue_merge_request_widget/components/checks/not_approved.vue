<script>
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import assignReviewersActionButton from '../../mixins/assign_reviewers_action_button';

export default {
  name: 'MergeChecksNotApproved',
  components: {
    MergeChecksMessage,
    ActionButtons,
  },
  mixins: [assignReviewersActionButton],
  props: {
    // eslint-disable-next-line vue/no-unused-properties -- mr prop is used by assignReviewersActionButton mixin
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <template #failed>
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />
    </template>
  </merge-checks-message>
</template>
