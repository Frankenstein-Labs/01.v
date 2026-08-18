<script>
import { GlCard, GlIcon, GlModal, GlLink, GlSprintf } from '@gitlab/ui';
import runnersJobsQueueDurationQuery from 'ee/ci/runner/graphql/list/runners_jobs_queue_duration.query.graphql';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, n__, sprintf, formatNumber } from '~/locale';
import { INSTANCE_TYPE } from '~/ci/runner/constants';

export default {
  name: 'RunnerPerformanceModal',
  components: {
    GlCard,
    GlIcon,
    GlLink,
    GlModal,
    GlSprintf,
  },
  props: {
    modalId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      skip: true,
      duration: null,
    };
  },
  apollo: {
    duration: {
      query: runnersJobsQueueDurationQuery,
      update(data) {
        return data.runners?.jobsStatistics?.queuedDuration?.p50;
      },
      variables() {
        return {
          type: INSTANCE_TYPE,
        };
      },
      skip() {
        return this.skip;
      },
    },
  },
  computed: {
    formattedDuration() {
      let formatted = '-';
      if (typeof this.duration === 'number') {
        formatted = formatNumber(this.duration);
      }
      return sprintf(
        n__(
          'Runners|%{highlightStart}%{duration}%{highlightEnd} second',
          'Runners|%{highlightStart}%{duration}%{highlightEnd} seconds',
          this.duration || 0,
        ),
        { duration: formatted },
      );
    },
  },
  methods: {
    onShown() {
      this.skip = false;
    },
  },
  helpPagePath: helpPagePath('ci/runners/runners_scope', {
    anchor: 'view-statistics-for-runner-performance',
  }),
  actionCancel: { text: __('Cancel') },
};
</script>
<template>
  <gl-modal
    :modal-id="modalId"
    size="sm"
    :action-cancel="$options.actionCancel"
    :no-focus-on-show="true"
    @shown="onShown"
  >
    <template #modal-title>
      {{ s__('Runners|Runner performance insights') }}
    </template>

    <p>
      <gl-sprintf
        :message="
          s__(
            'Runners|Understand how long it takes for runners to pick up a job. %{linkStart}How is this calculated?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.helpPagePath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <gl-card class="gl-text-center">
      <template #header>
        <span class="gl-font-bold">
          <gl-icon name="users" /> {{ s__('Runners|Instance: Median job queued time') }}
        </span>
      </template>
      <gl-sprintf :message="formattedDuration">
        <template #highlight="{ content }">
          <span class="gl-text-size-h-display gl-font-bold">{{ content }}</span>
        </template>
      </gl-sprintf>
    </gl-card>
  </gl-modal>
</template>
