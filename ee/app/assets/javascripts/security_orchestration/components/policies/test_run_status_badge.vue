<script>
import { GlBadge } from '@gitlab/ui';
import {
  TEST_RUN_STATE_CONFIG,
  DEFAULT_TEST_RUN_CONFIG,
} from 'ee/security_orchestration/components/policies/constants';
import { createSpepTestRunSubscription } from 'ee/security_orchestration/components/utils';

export default {
  name: 'TestRunStatusBadge',
  components: {
    GlBadge,
  },
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      testRunUpdated: createSpepTestRunSubscription('latestTestRun', 'liveTestRun'),
    },
  },
  props: {
    testRun: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      liveTestRun: null,
    };
  },
  computed: {
    testRunId() {
      return this.testRun?.id;
    },
    latestTestRun() {
      if (this.liveTestRun && this.testRunId === this.liveTestRun.id) {
        return this.liveTestRun;
      }
      return this.testRun;
    },
    shouldShowBadge() {
      return Boolean(this.latestTestRun);
    },
    badgeConfig() {
      return TEST_RUN_STATE_CONFIG[this.latestTestRun?.state] || DEFAULT_TEST_RUN_CONFIG;
    },
  },
  watch: {
    testRunId(newId) {
      if (this.liveTestRun && newId !== this.liveTestRun.id) {
        this.liveTestRun = null;
      }
    },
  },
};
</script>

<template>
  <gl-badge
    v-if="shouldShowBadge"
    :variant="badgeConfig.variant"
    :icon="badgeConfig.icon"
    size="sm"
    data-testid="test-run-badge"
  >
    {{ badgeConfig.text }}
  </gl-badge>
</template>
