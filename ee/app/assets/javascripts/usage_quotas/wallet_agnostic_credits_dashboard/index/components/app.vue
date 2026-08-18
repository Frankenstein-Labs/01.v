<script>
import maxBy from 'lodash-es/maxBy';
import { GlAlert, GlFormGroup, GlLink, GlSprintf, GlTab, GlTabs } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { getStartOfDay } from '~/lib/utils/datetime/date_calculation_utility';
import { PAGE_SIZE } from '../../../usage_billing/constants';
import subscriptionCreditsUsageQuery from '../graphql/get_subscription_credits_usage_overview.query.graphql';
import DateRangeFilter from '../../shared/components/date_range_filter.vue';
import {
  THIS_MONTH,
  LAST_MONTH,
  LAST_7_DAYS,
  LAST_30_DAYS,
  CUSTOM,
} from '../../shared/components/constants';
import CreditsConsumptionChart from './credits_consumption_chart.vue';
import ProductsDropdownFilter from './products_dropdown_filter.vue';
import ProductsList from './products_list.vue';
import UsageCards from './usage_cards.vue';
import UsersList from './users_list.vue';

// Local-time start-of-day so the picker's max date matches the user's calendar,
// not UTC (which can be a day ahead/behind for non-UTC timezones).
const getTodayLocal = () => getStartOfDay(new Date());

const DATE_RANGE_OPTIONS = [THIS_MONTH, LAST_MONTH, LAST_7_DAYS, LAST_30_DAYS, CUSTOM];

// reflects limit in ee/app/graphql/resolvers/gitlab_subscriptions/subscription_usage_resolver.rb
const MAX_DATE_RANGE_IN_DAYS = 366;

export default {
  name: 'WalletAgnosticCreditsDashboard',
  components: {
    DateRangeFilter,
    GlAlert,
    GlFormGroup,
    GlLink,
    GlSprintf,
    GlTab,
    GlTabs,
    ProductsList,
    UsageCards,
    UsersList,
    CreditsConsumptionChart,
    ProductsDropdownFilter,
  },
  inject: {
    namespacePath: {
      default: null,
    },
    userUsagePath: 'userUsagePath',
  },
  data() {
    return {
      subscriptionCreditsUsage: {},
      hasError: false,
      usersSortBy: 'totalCreditsUsed',
      usersSortAscending: false,
      selectedDateRange: { ...THIS_MONTH },
      usersPageInfo: {
        usersListAfter: null,
        usersListBefore: null,
        usersListFirst: PAGE_SIZE,
        usersListLast: null,
      },
      selectedProducts: [],
    };
  },
  apollo: {
    subscriptionCreditsUsage: {
      query: subscriptionCreditsUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
          usersListSort: this.usersListSort,
          startDate: this.selectedDateRange.startDate,
          endDate: this.selectedDateRange.endDate,
          flowTypes: this.selectedProducts ?? [],
          ...this.usersPageInfo,
        };
      },
      update({ subscriptionUsage }) {
        return subscriptionUsage ?? {};
      },
      error(error) {
        this.hasError = true;
        logError(error);
        captureException(error);
      },
      result({ error }) {
        if (!error) {
          this.hasError = false;
        }
      },
    },
  },
  computed: {
    usersListSort() {
      const direction = this.usersSortAscending ? 'asc' : 'desc';
      return `${convertToSnakeCase(this.usersSortBy)}_${direction}`.toUpperCase();
    },
    isLoading() {
      return this.$apollo.queries.subscriptionCreditsUsage.loading;
    },
    isUsageBillingDisabled() {
      return this.subscriptionCreditsUsage?.enabled === false;
    },
    subscriptionsUrl() {
      return gon?.subscriptions_url;
    },
    totalUsedCredits() {
      return this.subscriptionCreditsUsage.creditsUsed ?? 0;
    },
    activeUsersCount() {
      return this.subscriptionCreditsUsage.usersUsage?.totalActiveUsers ?? 0;
    },
    dailyAverage() {
      return this.subscriptionCreditsUsage.dailyAverage ?? 0;
    },
    peakDay() {
      const dailyUsage = this.subscriptionCreditsUsage.dailyUsage ?? [];

      return maxBy(dailyUsage, (usage) => usage.creditsUsed);
    },
    peakDayUsage() {
      return this.peakDay?.creditsUsed ?? 0;
    },
    peakDayDate() {
      return this.peakDay?.date ?? '';
    },
    shouldDisplayUserData() {
      return Boolean(gon?.display_gitlab_credits_user_data);
    },
    products() {
      return this.subscriptionCreditsUsage.products ?? [];
    },
    users() {
      return this.subscriptionCreditsUsage.usersUsage?.users ?? { nodes: [], pageInfo: {} };
    },
    productsForDropdown() {
      const catalog = this.subscriptionCreditsUsage.products ?? [];

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
  },
  displayUserDataHelpPath: helpPagePath('user/group/manage', {
    anchor: 'display-gitlab-credits-user-data',
  }),
  methods: {
    onUsersNextPage(cursor) {
      this.usersPageInfo = {
        usersListFirst: PAGE_SIZE,
        usersListAfter: cursor,
        usersListLast: null,
        usersListBefore: null,
      };
    },
    onUsersPrevPage(cursor) {
      this.usersPageInfo = {
        usersListFirst: null,
        usersListAfter: null,
        usersListLast: PAGE_SIZE,
        usersListBefore: cursor,
      };
    },
    setProductsFilter(products) {
      this.selectedProducts = products;
    },
    onUsersSortChange({ sortBy, sortAscending }) {
      this.usersSortBy = sortBy;
      this.usersSortAscending = sortAscending;
      this.usersPageInfo = {
        usersListAfter: null,
        usersListBefore: null,
        usersListFirst: PAGE_SIZE,
        usersListLast: null,
      };
    },
  },
  GITLAB_CREDITS_DOCS_URL: helpPagePath('subscriptions/gitlab_credits', {
    anchor: 'in-customers-portal',
  }),
  TODAY_LOCAL: getTodayLocal(),
  DATE_RANGE_OPTIONS,
  MAX_DATE_RANGE_IN_DAYS,
};
</script>

<template>
  <section>
    <div class="gl-mb-5">
      <h1 class="gl-mb-2">{{ s__('UsageBilling|GitLab Credits Overview') }}</h1>
      <p class="gl-text-subtle">
        {{
          s__('UsageBilling|Track monthly credit consumption and the main drivers of credit usage.')
        }}
      </p>
      <p class="gl-text-subtle" data-testid="usage-scope-copy">
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|This dashboard displays usage of all GitLab Duo Agent Platform features, including non-billable beta and experiment features. For billable usage only, view the %{linkStart}dashboard in Customers Portal%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.GITLAB_CREDITS_DOCS_URL" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>

    <div class="gl-flex gl-gap-7">
      <gl-form-group :label="s__('UsageBilling|Date range')">
        <date-range-filter
          v-model="selectedDateRange"
          :options="$options.DATE_RANGE_OPTIONS"
          :custom-date-range-limit="$options.MAX_DATE_RANGE_IN_DAYS"
          :custom-date-range-max-date="$options.TODAY_LOCAL"
        />
      </gl-form-group>

      <gl-form-group :label="s__('UsageBilling|Products')">
        <products-dropdown-filter
          :products="productsForDropdown"
          :loading="isLoading"
          @select="setProductsFilter"
        />
      </gl-form-group>
    </div>

    <div v-if="isLoading" data-testid="skeleton-loaders">
      <div class="gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
    </div>

    <gl-alert v-else-if="hasError" variant="danger" :dismissible="false" data-testid="error-alert">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <gl-alert
      v-else-if="isUsageBillingDisabled"
      data-testid="usage-billing-disabled-alert"
      variant="warning"
      class="gl-my-0"
      :dismissible="false"
    >
      {{ s__('UsageBilling|GitLab Credits dashboard is not available.') }}
    </gl-alert>

    <div v-else>
      <gl-alert
        v-if="subscriptionCreditsUsage.isOutdatedClient"
        data-testid="outdated-client-alert"
        variant="warning"
        class="gl-mb-7"
        :dismissible="false"
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

      <div class="gl-flex gl-flex-col gl-gap-7">
        <usage-cards
          :total-used-credits="totalUsedCredits"
          :active-users-count="activeUsersCount"
          :daily-average="dailyAverage"
          :peak-day-usage="peakDayUsage"
          :peak-day-date="peakDayDate"
        />

        <credits-consumption-chart
          :start-date="selectedDateRange.startDate"
          :end-date="selectedDateRange.endDate"
          :daily-usage="subscriptionCreditsUsage.dailyUsage"
          :total-credits="totalUsedCredits"
        />

        <gl-tabs>
          <gl-tab :title="s__('UsageBilling|Usage by user')">
            <users-list
              v-if="shouldDisplayUserData"
              :users="users"
              :user-usage-path="userUsagePath"
              :sort-by="usersSortBy"
              :sort-ascending="usersSortAscending"
              @next-page="onUsersNextPage"
              @prev-page="onUsersPrevPage"
              @sort-change="onUsersSortChange"
            />
            <div
              v-else
              data-testid="user-data-disabled-message"
              class="gl-mb-5 gl-mt-4 gl-text-subtle"
            >
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

          <gl-tab :title="s__('UsageBilling|Usage by product')">
            <products-list :products="products" :total-used-credits="totalUsedCredits" />
          </gl-tab>
        </gl-tabs>
      </div>
    </div>
  </section>
</template>
