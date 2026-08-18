<script>
import { GlButton } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { i18n } from 'ee/ai/constants';
import { InternalEvents } from '~/tracking';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

export default {
  i18n,
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    canTroubleshootJob: {
      type: Boolean,
      required: true,
    },
    jobStatusGroup: {
      type: String,
      required: true,
    },
    jobId: {
      type: Number,
      required: false,
      default: null,
    },
    jobGid: {
      type: String,
      required: false,
      default: '',
    },
    isBuild: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    resourceId() {
      return this.jobGid || convertToGraphQLId(TYPENAME_CI_BUILD, this.jobId);
    },
    jobFailed() {
      const failedGroups = ['failed', 'failed-with-warnings'];

      return failedGroups.includes(this.jobStatusGroup);
    },
    shouldDisplayButton() {
      return this.jobFailed && this.canTroubleshootJob && this.isBuild;
    },
  },
  mounted() {
    if (this.shouldDisplayButton) {
      this.trackEvent('render_root_cause_analysis');
    }
  },
  methods: {
    callDuo() {
      this.trackEvent('click_root_cause_analysis');

      sendDuoChatCommand({
        // eslint-disable-next-line @gitlab/no-hardcoded-urls -- Duo Chat command, not a navigational URL
        question: '/troubleshoot',
        resourceId: this.resourceId,
        agenticPrompt: this.$options.i18n.AGENTIC_PROMPT_TROUBLESHOOT_PIPELINE,
      });
    },
  },
};
</script>
<template>
  <gl-button
    v-if="shouldDisplayButton"
    icon="duo-chat"
    variant="confirm"
    data-testid="rca-duo-button"
    @click="callDuo"
  >
    {{ s__('Jobs|Troubleshoot') }}
  </gl-button>
</template>
