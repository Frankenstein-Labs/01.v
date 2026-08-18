<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AgentFlowErrorAlert',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
  },
  inject: {
    lastExecutorLogUrl: { default: () => '' },
  },
  props: {
    hasMessages: {
      type: Boolean,
      required: true,
    },
    errorSummary: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['dismiss'],
  computed: {
    lastExecutorUrl() {
      return this.lastExecutorLogUrl();
    },
    title() {
      if (this.hasMessages) {
        return s__('DuoAgentPlatform|Session failed');
      }
      return s__('DuoAgentPlatform|Session failed to start');
    },
    description() {
      if (this.hasMessages) {
        return s__('DuoAgentPlatform|This session started but failed before completing.');
      }
      return s__(
        'DuoAgentPlatform|This session encountered an error before any messages were recorded. Start a new session to try again.',
      );
    },
    extendedDescriptionWithExecutionUrl() {
      return s__(
        'DuoAgentPlatform|Review the %{linkStart}most recent job%{linkEnd} for details on what went wrong.',
      );
    },
  },
};
</script>
<template>
  <gl-alert
    class="gl-mx-3 gl-mt-3"
    :title="title"
    dismissible
    :dismiss-label="__('Dismiss')"
    variant="danger"
    data-testid="agent-flow-error-alert"
    @dismiss="$emit('dismiss')"
  >
    <template v-if="errorSummary">
      <span class="gl-break-words">{{ errorSummary }}</span>
    </template>
    <template v-else>
      {{ description }}
      <template v-if="hasMessages && lastExecutorUrl">
        <gl-sprintf :message="extendedDescriptionWithExecutionUrl">
          <template #link="{ content }">
            <gl-link :href="lastExecutorUrl" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </template>
  </gl-alert>
</template>
