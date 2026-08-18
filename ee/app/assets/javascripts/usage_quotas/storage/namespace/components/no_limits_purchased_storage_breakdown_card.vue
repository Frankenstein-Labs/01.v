<script>
import { GlCard, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'NoLimitsPurchasedStorageBreakdownCard',
  components: {
    HelpIcon,
    HelpPageLink,
    GlCard,
    GlSkeletonLoader,
    NumberToHumanSize,
  },
  props: {
    loading: {
      type: Boolean,
      required: true,
    },
    purchasedStorage: {
      type: Number,
      required: true,
    },
  },
  i18n: {
    PROJECT_ENFORCEMENT_PURCHASE_CARD_TITLE: s__('UsageQuota|Purchased storage'),
    PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE: s__(
      'UsageQuota|Any additional purchased storage will be displayed here.',
    ),
  },
};
</script>

<template>
  <gl-card>
    <gl-skeleton-loader v-if="loading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <div v-else>
      <div class="gl-flex gl-items-center gl-justify-between">
        <div class="gl-font-bold" data-testid="purchased-storage-card-title">
          {{ $options.i18n.PROJECT_ENFORCEMENT_PURCHASE_CARD_TITLE }}

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
      </div>
      <div class="gl-my-3 gl-text-size-h-display gl-font-bold gl-leading-1">
        <number-to-human-size
          label-class="gl-text-lg"
          :value="Number(purchasedStorage)"
          plain-zero
          data-testid="storage-purchased"
        />
      </div>
      <hr class="gl-my-4" />
      <p>{{ $options.i18n.PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE }}</p>
    </div>
  </gl-card>
</template>
