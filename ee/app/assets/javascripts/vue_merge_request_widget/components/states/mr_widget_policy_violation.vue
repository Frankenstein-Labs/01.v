<script>
import { s__ } from '~/locale';
import StateContainer from '~/vue_merge_request_widget/components/state_container.vue';
import BoldText from '~/vue_merge_request_widget/components/bold_text.vue';

const message = s__(
  'mrWidget|%{boldStart}Merge blocked:%{boldEnd} denied licenses must be removed.',
);

export default {
  name: 'MRWidgetPolicyViolation',
  message,
  components: {
    BoldText,
    StateContainer,
  },
};
</script>

<template>
  <state-container status="failed" is-collapsible>
    <bold-text :message="$options.message" />
  </state-container>
</template>
