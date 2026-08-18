<script>
import { GlAlert, GlFormGroup, GlLink, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import maxBy from 'lodash-es/maxBy';
import { logError } from '~/lib/logger';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import ProductsDropdownFilter from '../../../wallet_agnostic_credits_dashboard/index/components/products_dropdown_filter.vue';
import {
  CUSTOM,
  LAST_30_DAYS,
  LAST_7_DAYS,
  LAST_MONTH,
  THIS_MONTH,
  TODAY,
} from '../../../wallet_agnostic_credits_dashboard/shared/components/constants';
import DateRangeFilter from '../../../wallet_agnostic_credits_dashboard/shared/components/date_range_filter.vue';
import billingPeriodUsageQuery from '../graphql/get_billing_period_usage.query.graphql';
import userCreditsUsageQuery from '../graphql/get_user_credits_usage.query.graphql';
import TotalUsageCard from './total_usage_card.vue';
import UsageStatisticsCards from './usage_statistics_cards.vue';

const DATE_RANGE_OPTIONS = [THIS_MONTH, LAST_MONTH, LAST_7_DAYS, LAST_30_DAYS, CUSTOM];

// Usage is bucketed by UTC day, so the latest selectable date is the current
// UTC calendar date. The picker compares local calendar parts, hence the
// local-midnight date built from that UTC date: handing it the UTC-midnight
// `TODAY` would read as the previous day at negative offsets.
const MAX_SELECTABLE_DATE = newDate(toISODateFormat(TODAY, true));

// reflects limit in ee/app/graphql/resolvers/gitlab_subscriptions/subscription_usage_resolver.rb
const MAX_DATE_RANGE_IN_DAYS = 366;

export default {
  name: 'UserCreditsDashboardApp',
  components: {
    GlAlert,
    GlFormGroup,
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    DateRangeFilter,
    ProductsDropdownFilter,
    TotalUsageCard,
    UsageStatisticsCards,
  },
  inject: ['namespacePath'],
  data() {
    return {
      selfCreditsUsage: {},
      billingPeriodUsage: {},
      hasDashboardError: false,
      hasFilteredError: false,
      selectedDateRange: { ...THIS_MONTH },
      selectedProducts: [],
    };
  },
  apollo: {
    selfCreditsUsage: {
      query: userCreditsUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
          startDate: this.selectedDateRange.startDate,
          endDate: this.selectedDateRange.endDate,
          flowTypes: this.selectedProducts ?? [],
        };
      },
      update({ selfCreditsUsage }) {
        return selfCreditsUsage ?? {};
      },
      error(error) {
        this.hasFilteredError = true;
        logError(error);
        captureException(error);
      },
      result({ error }) {
        if (!error) {
          this.hasFilteredError = false;
        }
      },
    },
    // Dashboard-level query. Unfiltered, so the total usage card always
    // reflects the current billing period and the availability alerts are
    // never affected by a filter selection or its refetch.
    billingPeriodUsage: {
      query: billingPeriodUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
        };
      },
      update({ selfCreditsUsage }) {
        return selfCreditsUsage ?? {};
      },
      error(error) {
        this.hasDashboardError = true;
        logError(error);
        captureException(error);
      },
      result({ error }) {
        if (!error) {
          this.hasDashboardError = false;
        }
      },
    },
  },
  computed: {
    isDashboardLoading() {
      return this.$apollo.queries.billingPeriodUsage.loading;
    },
    // A filter change restarts this query, so this must never gate the filters
    // themselves: unmounting them mid-interaction drops their internal state.
    isFilteredLoading() {
      return this.$apollo.queries.selfCreditsUsage.loading;
    },
    isUsageBillingDisabled() {
      return this.billingPeriodUsage?.enabled === false;
    },
    isOutdatedClient() {
      return Boolean(this.billingPeriodUsage?.isOutdatedClient);
    },
    subscriptionsUrl() {
      return gon?.subscriptions_url;
    },
    billingPeriodCreditsUsed() {
      return this.billingPeriodUsage?.creditsUsed ?? 0;
    },
    billingPeriodStartDate() {
      return this.billingPeriodUsage?.startDate ?? null;
    },
    billingPeriodEndDate() {
      return this.billingPeriodUsage?.endDate ?? null;
    },
    productsForDropdown() {
      const catalog = this.selfCreditsUsage?.products ?? [];

      return catalog
        .map((product) => ({
          text: product.title,
          options: (product.flowTypes ?? []).map((flowType) => ({
            value: flowType.id,
            text: flowType.title,
          })),
        }))
        .filter((group) => group.options.length);
    },
    // Range-scoped stats reflect the selected date range and product filters.
    totalUsedCredits() {
      return this.selfCreditsUsage?.creditsUsed ?? 0;
    },
    dailyAverage() {
      return this.selfCreditsUsage?.dailyAverage ?? 0;
    },
    peakDay() {
      const dailyUsage = this.selfCreditsUsage?.dailyUsage ?? [];

      return maxBy(dailyUsage, (usage) => usage.creditsUsed);
    },
    peakDayUsage() {
      return this.peakDay?.creditsUsed ?? 0;
    },
    peakDayDate() {
      return this.peakDay?.date ?? '';
    },
  },
  methods: {
    setProductsFilter(products) {
      this.selectedProducts = products;
    },
  },
  MAX_SELECTABLE_DATE,
  DATE_RANGE_OPTIONS,
  MAX_DATE_RANGE_IN_DAYS,
};
</script>

<template>
  <section class="gl-grid gl-gap-4">
    <gl-skeleton-loader v-if="isDashboardLoading" data-testid="skeleton-loader" :lines="3" />

    <gl-alert
      v-else-if="hasDashboardError"
      variant="danger"
      :dismissible="false"
      data-testid="error-alert"
    >
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>
    <gl-alert
      v-else-if="isUsageBillingDisabled"
      variant="warning"
      class="gl-my-0"
      :dismissible="false"
      data-testid="usage-billing-disabled-alert"
    >
      {{ s__('UsageBilling|GitLab Credits dashboard is not available.') }}
    </gl-alert>

    <div v-else class="gl-flex gl-flex-col gl-gap-5" data-testid="user-credits-dashboard">
      <gl-alert
        v-if="isOutdatedClient"
        variant="warning"
        :dismissible="false"
        data-testid="outdated-client-alert"
      >
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|This dashboard may not display all GitLab Credits usage data. For complete visibility, please upgrade to the latest version of GitLab or visit the %{linkStart}Customer Portal%{linkEnd} for billable usage data.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="subscriptionsUrl" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>

      <total-usage-card
        :credits-used="billingPeriodCreditsUsed"
        :start-date="billingPeriodStartDate"
        :end-date="billingPeriodEndDate"
      />

      <div class="gl-flex gl-gap-7">
        <gl-form-group :label="s__('UsageBilling|Date range')">
          <date-range-filter
            v-model="selectedDateRange"
            :options="$options.DATE_RANGE_OPTIONS"
            :custom-date-range-limit="$options.MAX_DATE_RANGE_IN_DAYS"
            :custom-date-range-max-date="$options.MAX_SELECTABLE_DATE"
          />
        </gl-form-group>

        <gl-form-group :label="s__('UsageBilling|Products')">
          <products-dropdown-filter
            :products="productsForDropdown"
            :loading="isFilteredLoading"
            @select="setProductsFilter"
          />
        </gl-form-group>
      </div>

      <gl-skeleton-loader
        v-if="isFilteredLoading"
        data-testid="filtered-usage-skeleton-loader"
        :lines="3"
      />

      <gl-alert
        v-else-if="hasFilteredError"
        variant="danger"
        :dismissible="false"
        data-testid="filtered-usage-error-alert"
      >
        {{ s__('UsageBilling|An error occurred while fetching data') }}
      </gl-alert>

      <div v-else class="gl-grid gl-gap-4">
        <usage-statistics-cards
          :total-used-credits="totalUsedCredits"
          :daily-average="dailyAverage"
          :peak-day-usage="peakDayUsage"
          :peak-day-date="peakDayDate"
        />
      </div>
    </div>
  </section>
</template>
