<script>
import { GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import getGitlabSubscriptionQuery from 'ee/usage_quotas/seats/graphql/get_gitlab_subscription.query.graphql';
import getBillableMembersCountQuery from 'ee/subscriptions/graphql/queries/billable_members_count.query.graphql';
import SubscriptionSeatsStatisticsCard from 'ee/usage_quotas/seats/components/subscription_seats_statistics_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import PublicNamespacePlanInfoCard from 'ee/usage_quotas/seats/components/public_namespace_plan_info_card.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { PLAN_CODE_FREE } from 'ee/usage_quotas/seats/constants';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import SubscriptionUpgradeInfoCard from './subscription_upgrade_info_card.vue';
import SubscriptionUserList from './subscription_user_list.vue';

export default {
  name: 'SubscriptionSeats',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    PublicNamespacePlanInfoCard,
    SubscriptionSeatsStatisticsCard,
    StatisticsSeatsCard,
    SubscriptionUpgradeInfoCard,
    SubscriptionUserList,
    GlSkeletonLoader,
  },
  apollo: {
    billableMembersCount: {
      query: getBillableMembersCountQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.group.billableMembersCount;
      },
      error(error) {
        createAlert({
          message: s__('Billing|An error occurred while loading billable members list.'),
        });

        Sentry.captureException(error);
      },
    },
    plan: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update(data) {
        this.usage = data?.subscription?.usage;
        return data?.subscription?.plan;
      },
      error: (error) => {
        createAlert({
          message: s__('Billing|An error occurred while loading GitLab subscription details.'),
        });

        Sentry.captureException(error);
      },
    },
  },
  inject: [
    'fullPath',
    'isPublicNamespace',
    'explorePlansPath',
    'addSeatsHref',
    'namespaceId',
    'hasLimitedFreePlan',
  ],
  data() {
    return {
      plan: {},
      usage: {},
      billableMembersCount: 0,
    };
  },
  computed: {
    isPublicFreeNamespace() {
      return this.hasFreePlan && this.isPublicNamespace;
    },
    isLoaderShown() {
      return this.$apollo.loading;
    },
    hasFreePlan() {
      return this.plan.code === PLAN_CODE_FREE;
    },
    seatsInSubscription() {
      return this.usage?.seats_in_subscription;
    },
    activeTrial() {
      return Boolean(this.plan?.trial);
    },
    seatsOwed() {
      return this.usage?.seats_owed ?? 0;
    },
    maxSeatsUsed() {
      return this.usage?.max_seats_used ?? 0;
    },
  },
  methods: {
    refetchData() {
      this.$apollo.queries.plan.refetch();
      this.$apollo.queries.billableMembersCount.refetch();
    },
  },
};
</script>

<template>
  <section>
    <div class="gl-bg-subtle gl-p-5">
      <div
        v-if="isLoaderShown"
        class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2"
        data-testid="skeleton-loader-cards"
      >
        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>

        <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
          <gl-skeleton-loader :height="64">
            <rect width="140" height="30" x="5" y="0" rx="4" />
            <rect width="240" height="10" x="5" y="40" rx="4" />
            <rect width="340" height="10" x="5" y="54" rx="4" />
          </gl-skeleton-loader>
        </div>
      </div>
      <div v-else class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
        <subscription-seats-statistics-card
          :billable-members-count="billableMembersCount"
          :has-free-plan="hasFreePlan"
          :active-trial="activeTrial"
          :seats-in-subscription="seatsInSubscription"
        />
        <subscription-upgrade-info-card
          v-if="hasLimitedFreePlan"
          :explore-plans-path="explorePlansPath"
          :active-trial="activeTrial"
        />
        <public-namespace-plan-info-card v-else-if="isPublicFreeNamespace" />
        <!-- StatisticsSeatsCard will eventually be replaced. See https://gitlab.com/gitlab-org/gitlab/-/issues/429828 -->
        <statistics-seats-card
          v-else
          :has-free-plan="hasFreePlan"
          :seats-used="maxSeatsUsed"
          :seats-owed="seatsOwed"
          :purchase-button-link="addSeatsHref"
        />
      </div>
    </div>

    <subscription-user-list :has-free-plan="hasFreePlan" @refetch-data="refetchData" />
  </section>
</template>
