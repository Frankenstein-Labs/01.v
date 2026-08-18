<script>
import {
  GlIcon,
  GlPopover,
  GlLink,
  GlSkeletonLoader,
  GlProgressBar,
  GlTooltipDirective,
} from '@gitlab/ui';
import TimeboxStatusBadge from 'ee_component/iterations/components/timebox_status_badge.vue';
import { __, sprintf } from '~/locale';
import { humanTimeframe, localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { convertToGraphQLId } from '~/graphql_shared/utils';

import query from '~/issuable/popover/queries/iteration.query.graphql';

export default {
  name: 'IterationPopover',
  components: {
    GlIcon,
    GlPopover,
    GlLink,
    GlProgressBar,
    GlSkeletonLoader,
    TimeboxStatusBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    target: {
      type: HTMLAnchorElement,
      required: true,
    },
    iterationId: {
      type: String,
      required: true,
    },
    namespacePath: {
      type: String,
      required: true,
    },
    cachedTitle: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'top',
    },
  },
  data() {
    return {
      iteration: {},
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.iteration.loading;
    },
    title() {
      return this.iteration?.iterationCadence?.title || this.cachedTitle.split('%').slice(-1).pop();
    },
    iterationStats() {
      return this.iteration?.report?.stats || {};
    },
    groupFullPath() {
      return this.iteration?.group?.fullPath || '';
    },
    progress() {
      const complete = this.iterationStats.complete.count;
      const total = this.iterationStats.total.count;

      if (total !== 0) {
        return Math.floor((complete / total) * 100);
      }
      return 0;
    },
    showTimeframe() {
      return !this.loading && Boolean(this.iterationTimeframe);
    },
    showProgress() {
      return this.iterationStats.total && this.iterationStats.complete;
    },
    percentageComplete() {
      return sprintf(__('%{percentage}%% complete'), { percentage: this.progress });
    },
    iterationTimeframe() {
      const { startDate, dueDate } = this.iteration;
      const today = new Date();
      let timeframe = '';
      if (startDate && dueDate) {
        timeframe = humanTimeframe(newDate(startDate), newDate(dueDate));
      } else if (startDate && !dueDate) {
        const parsedStartDate = newDate(startDate);
        const startDateInWords = localeDateFormat.asDate.format(parsedStartDate);
        if (parsedStartDate.getTime() > today.getTime()) {
          timeframe = sprintf(__('Starts %{startDate}'), { startDate: startDateInWords });
        } else {
          timeframe = sprintf(__('Started %{startDate}'), { startDate: startDateInWords });
        }
      } else if (!startDate && dueDate) {
        const parsedDueDate = newDate(dueDate);
        const dueDateInWords = localeDateFormat.asDate.format(parsedDueDate);
        if (parsedDueDate.getTime() > today.getTime()) {
          timeframe = sprintf(__('Ends %{dueDate}'), { dueDate: dueDateInWords });
        } else {
          timeframe = sprintf(__('Ended %{dueDate}'), { dueDate: dueDateInWords });
        }
      }
      return timeframe;
    },
  },
  apollo: {
    iteration: {
      query,
      variables() {
        return {
          id: convertToGraphQLId(`Iteration`, this.iterationId),
          fullPath: this.namespacePath,
        };
      },
      update: (data) => data.iteration,
    },
  },
};
</script>

<template>
  <gl-popover
    :target="target"
    boundary="viewport"
    :placement="placement"
    :css-classes="['gl-min-w-34']"
    show
  >
    <div class="gl-mb-3 gl-flex gl-items-center gl-gap-2">
      <timebox-status-badge v-if="!loading" :state="iteration.state" />
      <span class="gl-flex gl-text-subtle" data-testid="iteration-label">
        <gl-icon name="iteration" class="gl-mr-1" variant="subtle" /> {{ __('Iteration') }}
      </span>
    </div>
    <gl-skeleton-loader v-if="loading" :height="15">
      <rect width="250" height="15" rx="4" />
    </gl-skeleton-loader>
    <div class="gl-max-w-30 gl-text-subtle" data-testid="iteration-cadence-title">
      {{ title }}
    </div>
    <gl-link
      v-if="showTimeframe"
      :href="iteration.webUrl"
      variant="meta"
      class="gl-text-base gl-font-bold"
      data-testid="iteration-timeframe"
    >
      {{ iterationTimeframe }}
    </gl-link>
    <template v-if="!loading">
      <div v-if="iteration.title" class="gl-text-subtle" data-testid="iteration-title">
        {{ iteration.title }}
      </div>
      <div
        v-if="showProgress"
        class="gl-mt-2 gl-flex gl-items-center gl-gap-2"
        data-testid="iteration-progress"
      >
        <gl-progress-bar :value="progress" variant="primary" class="gl-h-3 gl-grow" />
        <span>{{ percentageComplete }}</span>
      </div>
      <div
        v-if="groupFullPath"
        class="gl-mt-2 gl-flex gl-items-center gl-gap-3"
        data-testid="iteration-path"
      >
        <gl-icon name="group" />
        <span class="gl-text-subtle">{{ groupFullPath }}</span>
      </div>
    </template>
  </gl-popover>
</template>
