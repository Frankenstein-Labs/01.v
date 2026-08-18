<script>
import { GlKeysetPagination, GlAlert, GlAvatar, GlCard, GlLoadingIcon } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { PAGE_SIZE } from '../../../constants';
import getUserSubscriptionUsageQuery from '../graphql/get_user_subscription_usage.query.graphql';
import getUserSubscriptionUsageEvents from '../graphql/get_user_subscription_usage_events.query.graphql';
import { fillUsageValues, formatNumber } from '../../../utils';
import { processFlowTypes } from '../utils';
import EventsTable from './events_table.vue';
import FlowTypeFilter from './flow_type_filter.vue';

export default {
  name: 'UsageBillingUserDashboardApp',
  components: {
    GlCard,
    GlLoadingIcon,
    GlAlert,
    GlAvatar,
    GlKeysetPagination,
    HumanTimeframe,
    EventsTable,
    FlowTypeFilter,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    username: 'username',
    namespacePath: {
      default: null,
    },
  },
  data() {
    return {
      isUsageLoadingError: false,
      isEventsLoadingError: false,
      subscriptionUsage: null,
      userEvents: null,
      pagination: {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      },
      appliedFlowTypes: null,
    };
  },
  apollo: {
    subscriptionUsage: {
      query: getUserSubscriptionUsageQuery,
      variables() {
        return {
          // Note: namespacePath will be present on SaaS only, indicating a root group.
          // SM would pass null in this variable, requesting instance-level data.
          namespacePath: this.namespacePath,
          username: this.username,
        };
      },
      error(error) {
        this.isUsageLoadingError = true;
        logError(error);
        captureException(error);
      },
      update(data) {
        return data.subscriptionUsage;
      },
    },
    userEvents: {
      query: getUserSubscriptionUsageEvents,
      variables() {
        return {
          namespacePath: this.namespacePath,
          username: this.username,
          flowTypes: this.appliedFlowTypes,

          first: this.pagination.first,
          last: this.pagination.last,
          after: this.pagination.after,
          before: this.pagination.before,
        };
      },
      error(error) {
        this.isEventsLoadingError = true;
        logError(error);
        captureException(error);
      },
      update(data) {
        return data.subscriptionUsage.usersUsage.users.nodes[0];
      },
    },
  },
  computed: {
    isUsageBillingDisabled() {
      return this.subscriptionUsage?.enabled === false;
    },
    user() {
      return this.subscriptionUsage?.usersUsage?.users?.nodes?.[0];
    },
    usage() {
      return fillUsageValues(this.user?.usage);
    },
    totalCreditsUsed() {
      if (this.glFeatures.walletAgnosticCreditsDashboard) {
        return this.usage.totalCreditsUsed;
      }

      return (
        this.usage.creditsUsed +
        this.usage.monthlyCommitmentCreditsUsed +
        this.usage.monthlyWaiverCreditsUsed +
        this.usage.overageCreditsUsed +
        this.usage.paidTierTrialCreditsUsed
      );
    },
    events() {
      return this.userEvents?.events?.nodes ?? [];
    },
    pageInfo() {
      return this.userEvents?.events?.pageInfo;
    },
    usedFlowTypes() {
      const rawFlowTypes = this.user?.usedFlowTypes ?? [];

      return processFlowTypes(rawFlowTypes);
    },
    showIncludedCreditsCard() {
      return !this.glFeatures.walletAgnosticCreditsDashboard;
    },
    appliedFlowTypesWithFallback() {
      // When `appliedFlowTypes == null`, it means all options are selected
      if (this.appliedFlowTypes === null) {
        return this.usedFlowTypes.map((x) => x.value);
      }

      return this.appliedFlowTypes;
    },
  },
  methods: {
    formatNumber,
    onNextPage(item) {
      this.pagination = {
        first: PAGE_SIZE,
        after: item,
        last: null,
        before: null,
      };
    },
    onPrevPage(item) {
      this.pagination = {
        first: null,
        after: null,
        last: PAGE_SIZE,
        before: item,
      };
    },
    resetPagination() {
      this.pagination = {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      };
    },
    onFilterApply(selectedEventTypes) {
      // First query is fired with null value, indicating that this filter is not applied.
      // When all flow types are selected — we reset the selection list to null, to use cache from
      // the first query
      const areAllFlowTypesSelected = selectedEventTypes.length === this.usedFlowTypes.length;
      this.appliedFlowTypes = areAllFlowTypesSelected ? null : [...selectedEventTypes];
      this.resetPagination();
    },
  },
};
</script>
<template>
  <section>
    <gl-alert v-if="isUsageLoadingError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching usage data') }}
    </gl-alert>

    <div v-else-if="$apollo.queries.subscriptionUsage.loading">
      <gl-loading-icon />
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

    <template v-else>
      <header class="gl-my-5 gl-flex gl-flex-col gl-gap-3" data-testid="usage-billing-user-header">
        <div
          class="gl-mb-2 gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-3 @md/panel:gl-flex-row"
        >
          <div class="gl-flex gl-items-center">
            <gl-avatar
              :title="user.name"
              :alt="user.name"
              :src="user.avatarUrl"
              :entity-name="user.name"
              :size="64"
              class="gl-mr-3"
            />

            <div>
              <h1 class="gl-heading-1 gl-my-0">{{ user.name }}</h1>
              <p class="gl-my-0 gl-font-bold gl-text-subtle">@{{ user.username }}</p>
            </div>
          </div>
        </div>
      </header>

      <div
        class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
        data-testid="usage-billing-user-cards-row"
      >
        <gl-card
          v-if="showIncludedCreditsCard"
          data-testid="included-credits-card"
          class="gl-flex-1"
          body-class="gl-p-4"
        >
          <div
            class="gl-heading-scale-600 gl-mb-3 gl-font-bold"
            data-testid="included-credits-card-value"
          >
            {{ formatNumber(usage.creditsUsed) }}
            <span class="gl-heading-scale-600 gl-font-bold gl-text-subtle">
              / {{ formatNumber(usage.totalCredits) }}
            </span>
          </div>
          <div class="gl-font-bold">
            <p class="gl-my-0">
              {{ s__('UsageBillingUserDetails|included credits used this month') }}
            </p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              <human-timeframe
                :from="subscriptionUsage.startDate"
                :till="subscriptionUsage.endDate"
              />
            </p>
          </div>
        </gl-card>

        <gl-card data-testid="total-usage-card" class="gl-max-w-1/2 gl-flex-1" body-class="gl-p-4">
          <div class="gl-heading-scale-600 gl-mb-3 gl-font-bold">
            {{ formatNumber(totalCreditsUsed) }}
          </div>
          <div class="gl-font-bold">
            <p class="gl-my-0">{{ s__('UsageBillingUserDetails|total credits used') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              <human-timeframe
                :from="subscriptionUsage.startDate"
                :till="subscriptionUsage.endDate"
              />
            </p>
          </div>
        </gl-card>
      </div>

      <section data-testid="usage-billing-user-events-list">
        <div class="gl-mb-4 gl-flex gl-gap-3">
          <flow-type-filter
            :flow-types="usedFlowTypes"
            :applied-flow-types="appliedFlowTypesWithFallback"
            @apply="onFilterApply"
          />
        </div>

        <gl-alert v-if="isEventsLoadingError" variant="danger" class="gl-my-3">
          {{ s__('UsageBilling|An error occurred while fetching events list') }}
        </gl-alert>

        <div v-else-if="$apollo.queries.userEvents.loading">
          <gl-loading-icon />
        </div>

        <events-table v-else :events="events" />

        <div v-if="pageInfo" class="gl-mt-5 gl-flex gl-justify-center">
          <gl-keyset-pagination v-bind="pageInfo" @prev="onPrevPage" @next="onNextPage" />
        </div>
      </section>
    </template>
  </section>
</template>
