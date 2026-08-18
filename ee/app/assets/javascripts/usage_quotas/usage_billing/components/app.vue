<script>
import { GlAlert, GlSprintf, GlLink, GlTab, GlTabs } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { joinPaths } from 'jh_else_ce/lib/utils/url_utility';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { ensureAbsoluteCustomerPortalUrl } from '../utils';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import CurrentUsageCard from './current_usage_card.vue';
import CurrentOverageUsageCard from './current_overage_usage_card.vue';
import MonthlyWaiverCard from './monthly_waiver_card.vue';
import UsageTrendsChart from './usage_trends_chart.vue';
import UsageOverviewChart from './usage_overview_chart.vue';
import OverageOptInCard from './overage_opt_in_card.vue';
import PaidTierTrialPeriodView from './paid_tier_trial_period_view.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    GlTabs,
    GlTab,
    PageHeading,
    PurchaseCommitmentCard,
    UsageByUserTab,
    CurrentUsageCard,
    CurrentOverageUsageCard,
    MonthlyWaiverCard,
    UserDate,
    HumanTimeframe,
    UsageTrendsChart,
    UsageOverviewChart,
    OverageOptInCard,
    PaidTierTrialPeriodView,
  },
  mixins: [InternalEvents.mixin()],
  apollo: {
    subscriptionUsage: {
      query: getSubscriptionUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
        };
      },
      update({ subscriptionUsage }) {
        return subscriptionUsage ?? {};
      },
      error(error) {
        logError(error);
        captureException(error);
        this.isError = true;
      },
    },
  },
  inject: {
    namespacePath: { default: '' },
  },
  data() {
    return {
      isError: false,
      subscriptionUsage: {},
    };
  },
  computed: {
    isUsageBillingDisabled() {
      return this.subscriptionUsage?.enabled === false;
    },
    isOnPaidTierTrial() {
      return Boolean(this.subscriptionUsage?.paidTierTrial?.isActive);
    },
    shouldDisplayUserData() {
      return gon.display_gitlab_credits_user_data;
    },
    subscriptionsUrl() {
      return gon.subscriptions_url;
    },
    poolIsAvailable() {
      return Boolean(this.poolTotalCredits);
    },
    poolCreditsUsed() {
      return this.subscriptionUsage?.monthlyCommitment?.creditsUsed ?? 0;
    },
    poolTotalCredits() {
      return this.subscriptionUsage?.monthlyCommitment?.totalCredits ?? 0;
    },
    poolDailyUsage() {
      return this.subscriptionUsage?.monthlyCommitment?.dailyUsage ?? [];
    },
    overageIsAllowed() {
      return Boolean(this.subscriptionUsage?.overage?.isAllowed);
    },
    overageCreditsUsed() {
      return this.subscriptionUsage?.overage?.creditsUsed ?? 0;
    },
    overageDailyUsage() {
      return this.subscriptionUsage?.overage?.dailyUsage ?? [];
    },
    isLoading() {
      return this.$apollo.queries.subscriptionUsage.loading;
    },
    monthlyWaiverTotalCredits() {
      return this.subscriptionUsage?.monthlyWaiver?.totalCredits ?? 0;
    },
    monthlyWaiverCreditsUsed() {
      return this.subscriptionUsage?.monthlyWaiver?.creditsUsed ?? 0;
    },
    monthlyWaiverDailyUsage() {
      return this.subscriptionUsage?.monthlyWaiver?.dailyUsage ?? [];
    },
    isMonthlyWaiverAvailable() {
      return Boolean(this.monthlyWaiverTotalCredits);
    },
    paidTierTrialDailyUsage() {
      return this.subscriptionUsage?.paidTierTrial?.dailyUsage ?? [];
    },
    usersUsageDailyUsage() {
      return this.subscriptionUsage?.usersUsage?.dailyUsage ?? [];
    },
    usageTrendsTabIsAvailable() {
      return this.poolIsAvailable || this.isMonthlyWaiverAvailable || this.overageIsAllowed;
    },
    customersUsageDashboardUrl() {
      return ensureAbsoluteCustomerPortalUrl(
        this.subscriptionUsage.subscriptionPortalUsageDashboardUrl,
      );
    },
    purchaseCreditsUrl() {
      if (!this.subscriptionUsage.purchaseCreditsPath) return null;
      return joinPaths(gon.subscriptions_url, this.subscriptionUsage.purchaseCreditsPath);
    },
  },
  mounted() {
    this.trackEvent('view_usage_billing_pageload');
  },
  LONG_DATE_FORMAT_WITH_TZ,
  displayUserDataHelpPath: helpPagePath('user/group/manage', {
    anchor: 'display-gitlab-credits-user-data',
  }),
};
</script>
<template>
  <section>
    <page-heading class="gl-mb-6">
      <template #heading>
        <span data-testid="usage-billing-title">{{ s__('UsageBilling|GitLab Credits') }}</span>
      </template>
      <template #description>
        <div
          v-if="subscriptionUsage.startDate && subscriptionUsage.endDate"
          class="gl-mb-2 gl-text-lg gl-text-default"
        >
          <span class="gl-font-bold">
            {{ s__('UsageBilling|Usage period:') }}
          </span>
          <human-timeframe :from="subscriptionUsage.startDate" :till="subscriptionUsage.endDate" />
        </div>
        <div v-if="subscriptionUsage.lastEventTransactionAt" class="gl-text-sm">
          {{ s__('UsageBilling|Last event transaction at:') }}
          <user-date
            :date="subscriptionUsage.lastEventTransactionAt"
            :date-format="$options.LONG_DATE_FORMAT_WITH_TZ"
          />
        </div>
      </template>
    </page-heading>

    <gl-alert v-if="isError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <gl-alert
      v-if="subscriptionUsage.isOutdatedClient"
      data-testid="outdated-client-alert"
      variant="warning"
      class="gl-my-3"
    >
      <gl-sprintf
        :message="
          s__(
            'UsageBilling|This dashboard may not display all current subscription data. For complete visibility, please upgrade to the latest version of GitLab or visit the %{linkStart}Customer Portal%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="subscriptionsUrl" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <div v-if="isLoading" data-testid="skeleton-loaders">
      <section class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>

        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>
      </section>

      <div class="gl-mt-15 gl-flex gl-flex-col gl-gap-3">
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      </div>
    </div>

    <gl-alert
      v-else-if="isUsageBillingDisabled"
      data-testid="usage-billing-disabled-alert"
      variant="warning"
      class="gl-my-3"
      :dismissible="false"
    >
      {{ s__('UsageBilling|Usage Billing is disabled') }}
    </gl-alert>

    <paid-tier-trial-period-view
      v-else-if="isOnPaidTierTrial"
      :customers-usage-dashboard-url="customersUsageDashboardUrl"
      :purchase-credits-url="purchaseCreditsUrl"
      :month-start-date="subscriptionUsage.startDate"
      :month-end-date="subscriptionUsage.endDate"
      :commitment-daily-usage="poolDailyUsage"
      :waiver-daily-usage="monthlyWaiverDailyUsage"
      :overage-daily-usage="overageDailyUsage"
      :paid-tier-trial-daily-usage="paidTierTrialDailyUsage"
      :users-usage-daily-usage="usersUsageDailyUsage"
    />

    <template v-else>
      <section
        class="gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
        data-testid="usage-billing-cards-row"
      >
        <current-usage-card
          v-if="poolIsAvailable"
          :pool-total-credits="poolTotalCredits"
          :pool-credits-used="poolCreditsUsed"
          :month-end-date="subscriptionUsage.endDate"
        />

        <monthly-waiver-card
          v-if="isMonthlyWaiverAvailable && !overageCreditsUsed"
          :monthly-waiver-total-credits="monthlyWaiverTotalCredits"
          :monthly-waiver-credits-used="monthlyWaiverCreditsUsed"
        />

        <current-overage-usage-card
          v-else-if="overageIsAllowed || overageCreditsUsed"
          :overage-credits-used="overageCreditsUsed"
          :overage-is-allowed="overageIsAllowed"
          :monthly-waiver-credits-used="monthlyWaiverCreditsUsed"
        />

        <overage-opt-in-card
          v-if="subscriptionUsage.canAcceptOverageTerms"
          :customers-usage-dashboard-url="customersUsageDashboardUrl"
        />

        <purchase-commitment-card
          v-if="purchaseCreditsUrl"
          :has-commitment="poolIsAvailable"
          :purchase-credits-url="purchaseCreditsUrl"
        />
      </section>
      <gl-tabs class="gl-mt-5" lazy>
        <gl-tab
          v-if="usageTrendsTabIsAvailable"
          data-testid="usage-trends-tab"
          :title="s__('UsageBilling|Usage trends')"
          @click="trackEvent('click_usage_trend_tab_credits_dashboard')"
        >
          <usage-trends-chart
            :month-start-date="subscriptionUsage.startDate"
            :month-end-date="subscriptionUsage.endDate"
            :monthly-commitment-daily-usage="poolDailyUsage"
            :monthly-commitment-total-credits="poolTotalCredits"
            :monthly-commitment-is-available="poolIsAvailable"
            :monthly-waiver-daily-usage="monthlyWaiverDailyUsage"
            :monthly-waiver-total-credits="monthlyWaiverTotalCredits"
            :monthly-waiver-is-available="isMonthlyWaiverAvailable"
            :overage-daily-usage="overageDailyUsage"
            :overage-is-allowed="overageIsAllowed"
          />
        </gl-tab>
        <gl-tab
          data-testid="usage-overview-tab"
          :title="s__('UsageBilling|Usage overview')"
          @click="trackEvent('click_usage_overview_tab_credits_dashboard')"
        >
          <usage-overview-chart
            :month-start-date="subscriptionUsage.startDate"
            :month-end-date="subscriptionUsage.endDate"
            :commitment-daily-usage="poolDailyUsage"
            :waiver-daily-usage="monthlyWaiverDailyUsage"
            :overage-daily-usage="overageDailyUsage"
            :paid-tier-trial-daily-usage="paidTierTrialDailyUsage"
            :users-usage-daily-usage="usersUsageDailyUsage"
          />
        </gl-tab>
        <gl-tab
          data-testid="usage-by-user-tab"
          :title="s__('UsageBilling|Usage by user')"
          @click="trackEvent('click_usage_by_user_tab_credits_dashboard')"
        >
          <usage-by-user-tab v-if="shouldDisplayUserData" />
          <div v-else data-testid="user-data-disabled-alert" class="gl-mt-4 gl-text-subtle">
            <gl-sprintf
              :message="
                s__(
                  'UsageBilling|Displaying user data is disabled. %{linkStart}Learn how to enable it%{linkEnd}.',
                )
              "
            >
              <template #link="{ content }">
                <gl-link :href="$options.displayUserDataHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </div>
        </gl-tab>
      </gl-tabs>
    </template>
  </section>
</template>
