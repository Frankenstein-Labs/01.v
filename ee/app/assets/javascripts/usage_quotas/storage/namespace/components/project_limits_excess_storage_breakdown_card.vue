<script>
import { GlCard, GlButton, GlProgressBar, GlModalDirective, GlSkeletonLoader } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

/**
 * ProjectLimitsExcessStorageBreakdownCard
 *
 * This card is used on Namespace Usage quotas
 * when the namespace has Project-level storage limits
 * https://docs.gitlab.com/ee/user/storage_usage_quotas#project-storage-limit
 * It describes the relationship between excess storage and purchased storage
 */

export default {
  name: 'ProjectLimitsExcessStorageBreakdownCard',
  components: {
    HelpIcon,
    HelpPageLink,
    GlCard,
    GlButton,
    GlProgressBar,
    GlSkeletonLoader,
    NumberToHumanSize,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'subjectToHighLimit',
    'purchaseStorageUrl',
    'buyAddonTargetAttr',
    'totalRepositorySizeExcess',
    'perProjectStorageLimit',
    'namespacePlanName',
  ],
  props: {
    loading: {
      type: Boolean,
      required: true,
    },
    purchasedStorage: {
      type: Number,
      required: true,
    },
    limitedAccessModeEnabled: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    showPercentageInfo() {
      return this.purchasedStorage && this.totalRepositorySizeExcess;
    },
    percentageUsed() {
      const usedRatio = Math.max(
        Math.round((this.totalRepositorySizeExcess / this.purchasedStorage) * 100),
        0,
      );
      return Math.min(usedRatio, 100);
    },
    percentageUsedSubtitle() {
      return sprintf(s__('UsageQuota|You have used %{percentageUsed}%% of your total storage.'), {
        percentageUsed: this.percentageUsed,
      });
    },
    planStorageDescription() {
      const projectEnforcementTypeTitle = s__(
        'UsageQuota|Storage per project included in %{planName} subscription',
      );

      return sprintf(projectEnforcementTypeTitle, {
        planName: this.namespacePlanName,
      });
    },
    // ref_source tracks navigation context for CDOT conversion attribution
    purchaseStorageUrlWithRefSource() {
      return (
        this.purchaseStorageUrl &&
        mergeUrlParams({ ref_source: 'group_usage_quotas_page' }, this.purchaseStorageUrl)
      );
    },
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
          {{ s__('UsageQuota|Excess storage usage') }}

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
        <template v-if="purchaseStorageUrl && !subjectToHighLimit">
          <gl-button
            v-if="!limitedAccessModeEnabled"
            :href="purchaseStorageUrlWithRefSource"
            :target="buyAddonTargetAttr"
            category="primary"
            variant="confirm"
            data-testid="purchase-more-storage"
            class="gl-absolute gl-right-4 gl-top-4"
          >
            {{ s__('UsageQuota|Buy storage') }}
          </gl-button>
          <gl-button
            v-else
            v-gl-modal-directive="'limited-access-modal-id'"
            category="primary"
            variant="confirm"
            data-testid="purchase-more-storage"
            class="gl-absolute gl-right-4 gl-top-4"
          >
            {{ s__('UsageQuota|Buy storage') }}
          </gl-button>
        </template>
      </div>
      <div class="gl-my-3 gl-text-size-h-display gl-font-bold gl-leading-1">
        <number-to-human-size
          label-class="gl-text-lg"
          :value="Number(totalRepositorySizeExcess)"
          plain-zero
        />
        /
        <number-to-human-size
          label-class="gl-text-lg"
          :value="Number(purchasedStorage)"
          plain-zero
          data-testid="storage-purchased"
        />
      </div>
      <template v-if="showPercentageInfo">
        <gl-progress-bar :value="percentageUsed" class="gl-my-4" />
        <div data-testid="purchased-storage-percentage-used">
          {{ percentageUsedSubtitle }}
        </div>
      </template>
      <hr class="gl-my-4" />
      <p>
        {{
          s__(
            'UsageQuota|This namespace is under project-level limits, so only repository and LFS storage usage above the limit included in the plan is counted as excess storage. You can increase excess storage limit by purchasing storage packages.',
          )
        }}
      </p>
      <p v-if="perProjectStorageLimit">
        <strong><number-to-human-size :value="perProjectStorageLimit" /></strong>

        {{ planStorageDescription }}
      </p>
    </div>
  </gl-card>
</template>
