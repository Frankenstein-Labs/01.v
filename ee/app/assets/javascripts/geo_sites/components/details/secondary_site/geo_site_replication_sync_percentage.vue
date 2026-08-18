<script>
import { roundDownFloat } from '~/lib/utils/common_utils';

export default {
  name: 'GeoSiteReplicationSyncPercentage',
  props: {
    values: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    percent() {
      if (!this.values.length) {
        return null;
      }

      const { total, success } = this.values.reduce(
        (acc, v) => {
          acc.total += v?.total || 0;
          acc.success += v?.success || 0;
          return acc;
        },
        { total: 0, success: 0 },
      );

      const percent = roundDownFloat((success / total) * 100, 1);
      if (percent > 0 && percent < 1) {
        // Special case for very small numbers
        return '< 1';
      }

      // Display Not applicable when percent is not valide.
      return Number.isFinite(percent) ? percent : null;
    },
    percentColor() {
      if (this.percent === null) {
        return 'gl-bg-gray-200';
      }

      return this.percent === 100 ? 'gl-bg-green-500' : 'gl-bg-red-500';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-justify-end">
    <div
      :class="percentColor"
      class="gl-mr-2 gl-h-3 gl-w-3 gl-rounded-full"
      data-testid="geo-sync-percentage-indicator"
    ></div>
    <span class="gl-font-bold" data-testid="geo-sync-percentage">
      {{ percent === null ? `-%` : `${percent}%` }}
    </span>
  </div>
</template>
