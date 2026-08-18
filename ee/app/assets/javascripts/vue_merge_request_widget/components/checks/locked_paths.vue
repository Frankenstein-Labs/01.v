<script>
import { s__ } from '~/locale';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';

export default {
  name: 'MergeChecksLockedPaths',
  components: {
    MergeChecksMessage,
    ActionButtons,
  },
  props: {
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
  computed: {
    tertiaryActionsButtons() {
      return [
        this.mr.pathLocksPath && {
          href: this.mr.pathLocksPath,
          text: s__('MergeChecks|View locked files'),
        },
      ].filter((x) => x);
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
