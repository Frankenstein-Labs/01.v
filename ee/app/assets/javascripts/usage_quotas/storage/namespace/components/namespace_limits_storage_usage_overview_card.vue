<script>
import { GlCard, GlProgressBar } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'NamespaceLimitsStorageUsageOverviewCard',
  components: {
    GlCard,
    GlProgressBar,
    HelpIcon,
    HelpPageLink,
    NumberToHumanSize,
  },
  inject: ['namespaceStorageLimit'],
  props: {
    purchasedStorage: {
      type: Number,
      required: false,
      default: 0,
    },
    usedStorage: {
      type: Number,
      required: false,
      default: 0,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    totalStorageAvailable() {
      return this.namespaceStorageLimit + this.purchasedStorage;
    },
    percentageUsed() {
      // don't show the progress bar if there's no total storage
      if (!this.totalStorageAvailable) {
        return null;
      }

      const usedRatio = Math.max(
        Math.round((this.usedStorage / this.totalStorageAvailable) * 100),
        0,
      );

      return Math.min(usedRatio, 100);
    },
    percentageRemaining() {
      if (this.percentageUsed === null) {
        return null;
      }

      const percentageRemaining = Math.max(100 - this.percentageUsed, 0);

      return sprintf(s__('UsageQuota|%{percentageRemaining}%% namespace storage remaining.'), {
        percentageRemaining,
      });
    },
  },
};
</script>

<template>
  <gl-card>
    <div class="gl-font-bold" data-testid="namespace-storage-card-title">
      {{ s__('UsageQuota|Namespace storage used') }}

      <help-page-link
        href="user/storage_usage_quotas"
        anchor="view-storage"
        target="_blank"
        class="gl-ml-2"
        :aria-label="s__('UsageQuota|Learn more about usage quotas.')"
      >
        <help-icon />
      </help-page-link>
    </div>

    <div
      v-if="loading"
      class="gl-animate-skeleton-loader gl-my-3 gl-h-7 gl-max-w-26 gl-rounded-base"
    ></div>
    <div v-else class="gl-my-3 gl-text-size-h-display gl-font-bold gl-leading-1">
      <number-to-human-size label-class="gl-text-lg" :value="usedStorage" plain-zero />
      <template v-if="totalStorageAvailable">
        /
        <number-to-human-size label-class="gl-text-lg" :value="totalStorageAvailable" plain-zero />
      </template>
    </div>

    <template v-if="percentageUsed !== null">
      <div
        v-if="loading"
        class="gl-animate-skeleton-loader gl-mb-4 gl-h-2 !gl-max-w-none gl-rounded-base"
      ></div>
      <gl-progress-bar v-else :value="percentageUsed" class="gl-my-4" />

      <div
        v-if="loading"
        class="gl-animate-skeleton-loader gl-my-3 gl-h-5 gl-max-w-26 gl-rounded-base"
      ></div>
      <div v-else data-testid="namespace-storage-percentage-remaining">
        {{ percentageRemaining }}
      </div>
    </template>
  </gl-card>
</template>
