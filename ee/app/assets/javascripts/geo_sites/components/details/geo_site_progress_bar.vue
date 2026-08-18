<script>
import { GlPopover } from '@gitlab/ui';
import { toNumber } from 'lodash-es';
import { __, s__ } from '~/locale';
import StackedProgressBar from './stacked_progress_bar.vue';

export default {
  name: 'GeoSiteSyncProgress',
  i18n: {
    total: __('Total'),
  },
  components: {
    GlPopover,
    StackedProgressBar,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    values: {
      type: Object,
      required: false,
      default: null,
    },
    target: {
      type: String,
      required: false,
      default: null,
    },
    successLabel: {
      type: String,
      required: false,
      default: s__('Geo|Synced'),
    },
    queuedLabel: {
      type: String,
      required: false,
      default: s__('Geo|Queued'),
    },
    failedLabel: {
      type: String,
      required: false,
      default: __('Failed'),
    },
    unavailableLabel: {
      type: String,
      required: false,
      default: s__('Geo|Nothing to synchronize'),
    },
  },
  computed: {
    queuedCount() {
      return this.totalCount - this.successCount - this.failureCount;
    },
    totalCount() {
      return toNumber(this.values?.total) || 0;
    },
    failureCount() {
      return toNumber(this.values?.failed) || 0;
    },
    successCount() {
      return toNumber(this.values?.success) || 0;
    },
    popoverTarget() {
      return this.target ? this.target : `syncProgress-${this.title}`;
    },
  },
};
</script>

<template>
  <div v-if="values">
    <stacked-progress-bar
      :id="popoverTarget"
      tabindex="0"
      hide-tooltips
      :unavailable-label="unavailableLabel"
      :success-count="successCount"
      :failure-count="failureCount"
      :total-count="totalCount"
    />
    <gl-popover
      :target="popoverTarget"
      placement="right"
      triggers="hover focus"
      :css-classes="['gl-w-full']"
      :title="title"
    >
      <section>
        <div class="gl-my-3 gl-flex gl-items-center" data-testid="geo-progress-count">
          <div class="gl-mr-3 gl-h-2 gl-w-5 gl-bg-transparent"></div>
          <span class="gl-mr-4 gl-grow">{{ $options.i18n.total }}</span>
          <span class="gl-font-bold">{{ totalCount.toLocaleString() }}</span>
        </div>
        <div class="gl-my-3 gl-flex gl-items-center" data-testid="geo-progress-count">
          <div class="gl-mr-3 gl-h-2 gl-w-5 gl-bg-green-500"></div>
          <span class="gl-mr-4 gl-grow">{{ successLabel }}</span>
          <span class="gl-font-bold">{{ successCount.toLocaleString() }}</span>
        </div>
        <div class="gl-my-3 gl-flex gl-items-center" data-testid="geo-progress-count">
          <div class="gl-mr-3 gl-h-2 gl-w-5 gl-bg-gray-200"></div>
          <span class="gl-mr-4 gl-grow">{{ queuedLabel }}</span>
          <span class="gl-font-bold">{{ queuedCount.toLocaleString() }}</span>
        </div>
        <div class="gl-my-3 gl-flex gl-items-center" data-testid="geo-progress-count">
          <div class="gl-mr-3 gl-h-2 gl-w-5 gl-bg-red-500"></div>
          <span class="gl-mr-4 gl-grow">{{ failedLabel }}</span>
          <span class="gl-font-bold">{{ failureCount.toLocaleString() }}</span>
        </div>
      </section>
    </gl-popover>
  </div>
  <div v-else class="gl-text-sm gl-text-subtle">{{ __('Disabled') }}</div>
</template>
