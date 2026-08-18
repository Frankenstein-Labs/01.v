<script>
import { GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import {
  STATUS_DONE,
  STATUS_BLOCKED,
  STATUS_ERROR,
  RUNNER_TYPE_TO_TAB,
  DEFAULT_RUNNERS_TAB,
} from '~/pages/projects/shared/permissions/constants';
import duoWorkflowRunnerAvailableQuery from '../graphql/duo_workflow_runner_available.query.graphql';

export default {
  name: 'DuoReadinessRunnerRow',
  components: { DuoReadinessRow, GlButton },
  props: {
    readiness: {
      type: Object,
      required: true,
    },
    flowExecutionEnabled: {
      type: Boolean,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      available: Boolean(this.readiness.runnerAvailable),
      runnerType: this.readiness.usableRunnerType,
      rechecking: false,
    };
  },
  computed: {
    viewRunnersHref() {
      const tab = RUNNER_TYPE_TO_TAB[this.runnerType] || DEFAULT_RUNNERS_TAB;

      return mergeUrlParams({ tab }, this.readiness.runnersPath);
    },
    isBlocked() {
      return !this.available && !this.flowExecutionEnabled;
    },
    status() {
      if (this.available) return STATUS_DONE;

      return this.isBlocked ? STATUS_BLOCKED : STATUS_ERROR;
    },
    description() {
      if (this.available) {
        return s__('DuoAgentPlatform|A runner is available and picking up jobs.');
      }
      if (this.isBlocked) {
        return s__('DuoAgentPlatform|Needed once flow execution is on.');
      }

      return s__('DuoAgentPlatform|No runner this project can use, so flows would never start.');
    },
  },
  methods: {
    async recheck() {
      if (this.rechecking) return;

      this.rechecking = true;

      try {
        const { data } = await this.$apollo.query({
          query: duoWorkflowRunnerAvailableQuery,
          variables: { fullPath: this.projectFullPath },
          fetchPolicy: 'no-cache',
        });

        const available = data?.project?.duoWorkflowRunnerAvailable;

        // Field-level authorization redacts to a bare null with no error; not "no runner".
        if (available == null) {
          createAlert({
            message: s__(
              'DuoAgentPlatform|Could not check for a runner. You do not have permission to check this project.',
            ),
          });
        } else {
          this.available = available;
          this.runnerType = data.project.duoWorkflowUsableRunnerType;
        }
      } catch (error) {
        createAlert({
          message: s__('DuoAgentPlatform|Could not check for a runner. Try again.'),
          error,
          captureError: true,
        });
      } finally {
        this.rechecking = false;
      }
    },
  },
  i18n: {
    title: s__('DuoAgentPlatform|CI/CD runner'),
    viewRunners: s__('DuoAgentPlatform|View runners'),
    checkAgain: s__('DuoAgentPlatform|Check again'),
  },
};
</script>

<template>
  <duo-readiness-row :title="$options.i18n.title" :description="description" :status="status">
    <gl-button
      v-if="available"
      category="tertiary"
      size="small"
      :href="viewRunnersHref"
      target="_blank"
      data-testid="runner-row-action"
    >
      {{ $options.i18n.viewRunners }}
    </gl-button>
    <gl-button
      v-else
      category="secondary"
      size="small"
      icon="retry"
      :disabled="!flowExecutionEnabled"
      :loading="rechecking"
      data-testid="runner-row-action"
      @click="recheck"
    >
      {{ $options.i18n.checkAgain }}
    </gl-button>
  </duo-readiness-row>
</template>
