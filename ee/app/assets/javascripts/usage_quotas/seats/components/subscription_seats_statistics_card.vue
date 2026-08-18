<script>
import { GlLink, GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { __, s__, n__, sprintf } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import { seatsInUseLink } from 'ee/usage_quotas/seats/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

export default {
  name: 'SubscriptionSeatsStatisticsCard',
  components: { GlLink, GlSkeletonLoader, UsageStatistics, HelpIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['maxFreeNamespaceSeats', 'namespaceId', 'hasLimitedFreePlan'],
  props: {
    billableMembersCount: {
      type: Number,
      required: false,
      default: 0,
    },
    hasFreePlan: {
      type: Boolean,
      required: false,
      default: false,
    },
    activeTrial: {
      type: Boolean,
      required: false,
      default: false,
    },
    seatsInSubscription: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      communityPlan: false,
    };
  },
  apollo: {
    communityPlan: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update: (data) => Boolean(data.subscription?.communityPlan),
      error: (error) => {
        const { networkError } = error;
        networkError?.result?.errors.forEach(({ message }) => Sentry.captureException(message));
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    freeNamespaceSeatsLimitText() {
      return sprintf(s__('Billings|Free groups are limited to %{number} seats.'), {
        number: this.maxFreeNamespaceSeats,
      });
    },
    percentage() {
      if (this.hasFreePlan || this.seatsInSubscription === 0 || this.activeTrial) return null;

      return Math.round((this.billableMembersCount * 100) / this.totalSeatsInSubscription);
    },
    seatsStatisticsText() {
      if (this.communityPlan) return s__('Billings|Open source Plan Seats used');
      if (this.hasFreePlan) return s__('Billings|Free seats used');
      if (this.hasLimitedFreePlan) return s__('Billings|Seats in use / Seats available');
      return s__('Billings|Seats in use / Seats in subscription');
    },
    shouldDisplayLimitedSeatText() {
      return this.hasFreePlan || this.hasLimitedFreePlan || this.activeTrial;
    },
    totalSeatsInSubscription() {
      return this.hasLimitedFreePlan ? this.maxFreeNamespaceSeats : this.seatsInSubscription;
    },
    totalSeatsInSubscriptionToDisplay() {
      const unlimited = __('Unlimited');

      if (this.activeTrial) return unlimited;

      return this.totalSeatsInSubscription ? String(this.totalSeatsInSubscription) : unlimited;
    },
    helpLinkConfig() {
      if (this.communityPlan) {
        return {
          href: `${PROMO_URL}/solutions/open-source/`,
          tooltipText: s__('Billings|Learn more about billing and seat usage.'),
        };
      }

      if (!this.hasLimitedFreePlan) {
        return {
          href: seatsInUseLink,
          tooltipText: s__('Billings|Learn more about billing and seat usage.'),
        };
      }

      if (this.activeTrial) {
        return {
          href: seatsInUseLink,
          tooltipText: s__('Billings|Learn more about billing and seat usage.'),
        };
      }

      return {
        href: seatsInUseLink,
        tooltipText: this.freeNamespaceSeatsLimitText,
      };
    },
    additionalInfo() {
      if (this.maxFreeNamespaceSeats && (this.hasLimitedFreePlan || this.activeTrial)) {
        return n__(
          'Billings|Groups in the Free tier are limited to %d seat',
          'Billings|Groups in the Free tier are limited to %d seats',
          this.maxFreeNamespaceSeats,
        );
      }

      return s__('Billings|You have unlimited seat count.');
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-rounded-base gl-border-section gl-bg-section gl-p-6"
    data-testid="container"
  >
    <div v-if="$apollo.loading">
      <gl-skeleton-loader :height="64">
        <rect width="140" height="30" x="5" y="0" rx="4" />
        <rect width="240" height="10" x="5" y="40" rx="4" />
        <rect width="340" height="10" x="5" y="54" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <usage-statistics
        :percentage="percentage"
        :total-value="totalSeatsInSubscriptionToDisplay"
        :usage-value="String(billableMembersCount)"
      >
        <template #additional-info>
          <p v-if="seatsStatisticsText" class="gl-mb-0 gl-font-bold" data-testid="seats-info">
            {{ seatsStatisticsText }}
            <gl-link
              v-if="helpLinkConfig.href"
              v-gl-tooltip
              :href="helpLinkConfig.href"
              target="_blank"
              class="gl-ml-2"
              :title="helpLinkConfig.tooltipText"
              :aria-label="helpLinkConfig.tooltipText"
            >
              <help-icon />
            </gl-link>
          </p>
          <p
            v-if="shouldDisplayLimitedSeatText"
            class="!gl-border-t gl-mt-5 !gl-border-t-gray-300 !gl-pt-5"
          >
            {{ additionalInfo }}
          </p>
        </template>
      </usage-statistics>
    </template>
  </div>
</template>
