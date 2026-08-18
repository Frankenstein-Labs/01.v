<script>
import { GlCard } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

/**
 * NamespaceLimitsTotalStorageAvailableBreakdownCard
 *
 * This card is used on Namespace Usage quotas
 * when the namespace has Namespace-level storage limits
 * https://docs.gitlab.com/ee/user/storage_usage_quotas#namespace-storage-limit
 * It breaks down the storage available: included in the plan & purchased storage
 */

export default {
  name: 'NamespaceLimitsTotalStorageAvailableBreakdownCard',
  components: { HelpIcon, HelpPageLink, GlCard, NumberToHumanSize },
  inject: ['namespacePlanName', 'namespaceStorageLimit'],
  props: {
    purchasedStorage: {
      type: Number,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    planStorageDescription() {
      return sprintf(s__('UsageQuota|Included in %{planName} subscription'), {
        planName: this.namespacePlanName,
      });
    },
    totalStorageAvailable() {
      return this.namespaceStorageLimit + this.purchasedStorage;
    },
  },
};
</script>

<template>
  <gl-card data-testid="storage-detail-card">
    <div class="gl-flex gl-justify-between gl-gap-5" data-testid="storage-included-in-plan">
      <div class="gl-w-80p">{{ planStorageDescription }}</div>
      <div v-if="loading" class="gl-animate-skeleton-loader gl-h-5 gl-w-8 gl-rounded-base"></div>
      <number-to-human-size v-else class="gl-whitespace-nowrap" :value="namespaceStorageLimit" />
    </div>
    <div class="gl-flex gl-justify-between">
      <div class="gl-w-80p">
        {{ s__('UsageQuota|Total purchased storage') }}
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
      <div v-if="loading" class="gl-animate-skeleton-loader gl-h-5 gl-w-8 gl-rounded-base"></div>
      <number-to-human-size
        v-else
        class="gl-whitespace-nowrap"
        :value="purchasedStorage"
        data-testid="storage-purchased"
      />
    </div>
    <hr />
    <div class="gl-flex gl-justify-between">
      <div class="gl-w-80p">{{ s__('UsageQuota|Total storage') }}</div>
      <div v-if="loading" class="gl-animate-skeleton-loader gl-h-5 gl-w-8 gl-rounded-base"></div>
      <number-to-human-size
        v-else
        class="gl-whitespace-nowrap"
        :value="totalStorageAvailable"
        data-testid="total-storage"
      />
    </div>
  </gl-card>
</template>
