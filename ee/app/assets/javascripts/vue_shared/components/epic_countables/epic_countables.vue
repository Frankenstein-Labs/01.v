<script>
import { GlAlert, GlPopover, GlSprintf, GlIcon } from '@gitlab/ui';
import { epicCountPermissionText } from './constants';

export default {
  name: 'EpicCountablesEE',
  components: {
    GlAlert,
    GlPopover,
    GlSprintf,
    GlIcon,
  },
  props: {
    allowSubEpics: {
      type: Boolean,
      required: false,
      default: false,
    },
    openedEpicsCount: {
      type: Number,
      required: true,
    },
    closedEpicsCount: {
      type: Number,
      required: true,
    },
    openedIssuesCount: {
      type: Number,
      required: true,
    },
    closedIssuesCount: {
      type: Number,
      required: true,
    },
    openedIssuesWeight: {
      type: Number,
      required: true,
    },
    closedIssuesWeight: {
      type: Number,
      required: true,
    },
  },
  computed: {
    totalEpicsCount() {
      return this.openedEpicsCount + this.closedEpicsCount;
    },
    totalIssuesCount() {
      return this.openedIssuesCount + this.closedIssuesCount;
    },
    totalChildrenCount() {
      return this.totalEpicsCount + this.totalIssuesCount;
    },
    shouldRenderEpicProgress() {
      return this.totalWeight > 0;
    },
    totalProgress() {
      return Math.round((this.closedIssuesWeight / this.totalWeight) * 100);
    },
    totalWeight() {
      return this.openedIssuesWeight + this.closedIssuesWeight;
    },
  },
  i18n: {
    epicCountPermissionText,
  },
};
</script>

<template>
  <span>
    <gl-popover :target="() => $refs.countBadge">
      <p v-if="allowSubEpics" class="gl-m-0 gl-font-bold">
        {{ __('Epics') }} &#8226;
        <span class="gl-font-normal">
          <gl-sprintf :message="__('%{openedEpics} open, %{closedEpics} closed')">
            <template #openedEpics>{{ openedEpicsCount }}</template>
            <template #closedEpics>{{ closedEpicsCount }}</template>
          </gl-sprintf>
        </span>
      </p>
      <p class="gl-m-0 gl-font-bold">
        {{ __('Issues') }} &#8226;
        <span class="gl-font-normal">
          <gl-sprintf :message="__('%{openedIssues} open, %{closedIssues} closed')">
            <template #openedIssues>{{ openedIssuesCount }}</template>
            <template #closedIssues>{{ closedIssuesCount }}</template>
          </gl-sprintf>
        </span>
      </p>
      <p class="gl-m-0 gl-font-bold">
        {{ __('Total weight') }} &#8226;
        <span class="gl-font-normal" data-testid="epic-countables-total-weight">
          {{ totalWeight }}
        </span>
      </p>
      <gl-alert v-if="totalChildrenCount > 0" :dismissible="false" class="gl-mb-3 gl-max-w-26">
        {{ $options.i18n.epicCountPermissionText }}
      </gl-alert>
    </gl-popover>

    <gl-popover v-if="shouldRenderEpicProgress" :target="() => $refs.progressBadge">
      <p class="gl-m-0 gl-font-bold">
        {{ __('Progress') }} &#8226;
        <span class="gl-font-normal" data-testid="epic-progress-popover-content">
          <gl-sprintf :message="__('%{completedWeight} of %{totalWeight} weight completed')">
            <template #completedWeight>{{ closedIssuesWeight }}</template>
            <template #totalWeight>{{ totalWeight }}</template>
          </gl-sprintf>
        </span>
      </p>
      <gl-alert :dismissible="false" class="gl-mb-3 gl-max-w-26">
        {{ $options.i18n.epicCountPermissionText }}
      </gl-alert>
    </gl-popover>

    <span ref="countBadge" class="issue-count-badge gl-mr-0 gl-cursor-help gl-pr-0 gl-text-subtle">
      <span v-if="allowSubEpics" class="gl-mr-3">
        <gl-icon name="epic" />
        {{ totalEpicsCount }}
      </span>
      <span class="gl-mr-3" data-testid="epic-countables-counts-issues">
        <gl-icon name="issues" />
        {{ totalIssuesCount }}
      </span>
      <span class="gl-mr-3" data-testid="epic-countables-weight-issues">
        <gl-icon name="weight" />
        {{ totalWeight }}
      </span>
    </span>

    <span
      v-if="shouldRenderEpicProgress"
      ref="progressBadge"
      class="issue-count-badge gl-cursor-help gl-pl-0 gl-text-subtle"
    >
      <span class="gl-mr-3" data-testid="epic-progress">
        <gl-icon name="progress" />
        {{ totalProgress }}%
      </span>
    </span>
  </span>
</template>
