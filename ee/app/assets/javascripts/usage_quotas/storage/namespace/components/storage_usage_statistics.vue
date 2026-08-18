<script>
import { GlSprintf, GlButton, GlModalDirective } from '@gitlab/ui';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import StorageUsageOverviewCard from '~/usage_quotas/storage/namespace/components/storage_usage_overview_card.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import LimitedAccessModal from '../../../components/limited_access_modal.vue';
import NamespaceLimitsStorageUsageOverviewCard from './namespace_limits_storage_usage_overview_card.vue';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from './namespace_limits_total_storage_available_breakdown_card.vue';
import ProjectLimitsExcessStorageBreakdownCard from './project_limits_excess_storage_breakdown_card.vue';
import NoLimitsPurchasedStorageBreakdownCard from './no_limits_purchased_storage_breakdown_card.vue';

export default {
  name: 'StorageUsageStatisticsEE',
  components: {
    GlSprintf,
    HelpPageLink,
    GlButton,
    LimitedAccessModal,
    NamespaceLimitsStorageUsageOverviewCard,
    NamespaceLimitsTotalStorageAvailableBreakdownCard,
    StorageUsageOverviewCard,
    ProjectLimitsExcessStorageBreakdownCard,
    NumberToHumanSize,
    NoLimitsPurchasedStorageBreakdownCard,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'purchaseStorageUrl',
    'buyAddonTargetAttr',
    'namespacePlanName',
    'aboveSizeLimit',
    'subjectToHighLimit',
    'isUsingProjectEnforcementWithLimits',
    'isUsingProjectEnforcementWithNoLimits',
    'isUsingNamespaceEnforcement',
    'isInNamespaceLimitsPreEnforcement',
    'perProjectStorageLimit',
    'namespaceStorageLimit',
    'namespaceId',
  ],
  apollo: {
    // handling loading state is not needed in the first iteration of https://gitlab.com/gitlab-org/gitlab/-/issues/409750
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: parseInt(this.namespaceId, 10),
        };
      },
      update: (data) => ({
        ...data.subscription,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      skip() {
        return !this.$apollo.provider.clients.customersDotClient;
      },
    },
  },
  props: {
    additionalPurchasedStorageSize: {
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
  data() {
    return {
      subscriptionPermissions: {},
      isLimitedAccessModalShown: false,
    };
  },
  computed: {
    isPurchaseButtonShown() {
      return (
        this.purchaseStorageUrl &&
        (this.isUsingProjectEnforcementWithNoLimits || this.isUsingNamespaceEnforcement) &&
        !this.$apollo.queries.subscriptionPermissions.loading
      );
    },
    shouldShowLimitedAccessModal() {
      // NOTE: we're using existing flag for seats `canAddSeats`, to infer
      // whether the storage is expandable.
      const canAddStorage = this.subscriptionPermissions?.canAddSeats ?? true;

      return !canAddStorage && LIMITED_ACCESS_KEYS.includes(this.subscriptionPermissions.reason);
    },
    shouldShowLimitUI() {
      return !this.subjectToHighLimit || this.aboveSizeLimit;
    },
    // ref_source tracks navigation context for CDOT conversion attribution
    purchaseStorageUrlWithRefSource() {
      return (
        this.purchaseStorageUrl &&
        mergeUrlParams({ ref_source: 'group_usage_quotas_page' }, this.purchaseStorageUrl)
      );
    },
  },
  methods: {
    showLimitedAccessModal() {
      this.isLimitedAccessModalShown = true;
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-flex gl-items-center gl-justify-between">
      <h2 class="gl-heading-2 gl-my-3" data-testid="overview-subtitle">
        {{ s__('UsageQuota|Namespace overview') }}
      </h2>
      <template v-if="isPurchaseButtonShown">
        <gl-button
          v-if="!shouldShowLimitedAccessModal"
          :href="purchaseStorageUrlWithRefSource"
          :target="buyAddonTargetAttr"
          category="primary"
          variant="confirm"
          data-testid="purchase-more-storage"
        >
          {{ s__('UsageQuota|Buy storage') }}
        </gl-button>

        <gl-button
          v-else
          v-gl-modal-directive="'limited-access-modal-id'"
          category="primary"
          variant="confirm"
          data-testid="purchase-more-storage"
          @click="showLimitedAccessModal"
        >
          {{ s__('UsageQuota|Buy storage') }}
        </gl-button>
      </template>
    </div>
    <p class="gl-mb-0">
      <template v-if="namespaceStorageLimit && isUsingNamespaceEnforcement">
        <gl-sprintf :message="s__('UsageQuota|This namespace has %{planLimit} of storage.')">
          <template #planLimit><number-to-human-size :value="namespaceStorageLimit" /></template>
        </gl-sprintf>
        <help-page-link href="user/storage_usage_quotas" anchor="view-storage">
          {{ s__('UsageQuota|How are limits applied?') }}</help-page-link
        >
      </template>

      <template v-if="isUsingProjectEnforcementWithLimits && shouldShowLimitUI">
        <gl-sprintf
          :message="
            s__(
              'UsageQuota|Projects under this namespace have %{planLimit} of storage limit applied to repository and LFS objects.',
            )
          "
        >
          <template #planLimit><number-to-human-size :value="perProjectStorageLimit" /></template>
        </gl-sprintf>
        <help-page-link
          v-if="purchaseStorageUrl"
          href="user/storage_usage_quotas"
          anchor="view-storage"
        >
          {{ s__('UsageQuota|How are limits applied?') }}
        </help-page-link>
        <help-page-link
          v-else
          href="administration/settings/account_and_limit_settings"
          anchor="repository-size-limit"
        >
          {{ s__('UsageQuota|How are limits applied?') }}
        </help-page-link>
      </template>
    </p>
    <div class="gl-grid gl-gap-5 gl-py-4 @md/panel:gl-grid-cols-2">
      <namespace-limits-storage-usage-overview-card
        v-if="isUsingNamespaceEnforcement"
        :used-storage="usedStorage"
        :purchased-storage="additionalPurchasedStorageSize"
        :loading="loading"
        data-testid="namespace-usage-total-content"
      />

      <storage-usage-overview-card
        v-else
        :used-storage="usedStorage"
        :loading="loading"
        data-testid="namespace-usage-total-content"
      />

      <template v-if="namespacePlanName">
        <no-limits-purchased-storage-breakdown-card
          v-if="isUsingProjectEnforcementWithNoLimits && !isInNamespaceLimitsPreEnforcement"
          :purchased-storage="additionalPurchasedStorageSize"
          :limited-access-mode-enabled="shouldShowLimitedAccessModal"
          :loading="loading"
        />

        <project-limits-excess-storage-breakdown-card
          v-else-if="isUsingProjectEnforcementWithLimits && shouldShowLimitUI"
          :purchased-storage="additionalPurchasedStorageSize"
          :limited-access-mode-enabled="shouldShowLimitedAccessModal"
          :loading="loading"
        />

        <namespace-limits-total-storage-available-breakdown-card
          v-else-if="isUsingNamespaceEnforcement || isInNamespaceLimitsPreEnforcement"
          :purchased-storage="additionalPurchasedStorageSize"
          :loading="loading"
        />
      </template>
    </div>
    <limited-access-modal
      v-if="shouldShowLimitedAccessModal"
      v-model="isLimitedAccessModalShown"
      :limited-access-reason="subscriptionPermissions.reason"
    />
  </div>
</template>
