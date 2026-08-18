<script>
import { GlCard, GlButton, GlIcon } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import { DUO_PRO, SELF_HOSTED_DAP, DUO_IDENTIFIERS, DUO_TITLES } from 'ee/constants/duo';
import { InternalEvents } from '~/tracking';
import { formatDate } from '~/lib/utils/datetime_utility';

export default {
  name: 'DuoSeatUtilizationInfoCard',
  i18n: {
    duoSeatUtilizationTitle: s__('UsageQuota|Seat utilization'),
    duoSeatUtilizationDescriptionText: s__(
      `CodeSuggestions|A user can be assigned a %{title} seat only once each billable month.`,
    ),
    duoSubscriptionStartText: s__(`AiPowered|Start date: %{startDate}`),
    duoSubscriptionEndText: s__(`AiPowered|End date: %{endDate}`),
    duoAssignSeatsButtonText: s__('AiPowered|Assign seats'),
    duoPurchaseSeatsButtonText: __('Purchase seats'),
  },
  components: {
    GlCard,
    GlButton,
    GlIcon,
    UsageStatistics,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['addDuoProHref', 'duoSeatUtilizationPath', 'duoAddOnStartDate', 'duoAddOnEndDate'],
  props: {
    usageValue: {
      type: Number,
      required: true,
    },
    totalValue: {
      type: Number,
      required: true,
    },
    activeDuoTier: {
      type: String,
      required: true,
      validator: (val) => DUO_IDENTIFIERS.includes(val),
    },
    addOnPurchases: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    percentage() {
      return Math.floor((this.usageValue / this.totalValue) * 100);
    },
    duoTitle() {
      return DUO_TITLES[this.activeDuoTier];
    },
    showPurchaseSeatsButton() {
      // Hide the button for instances with the Self-Hosted Duo Agent Platform add-on,
      // since self-service purchase of it is currently not supported. See:
      // https://gitlab.com/gitlab-org/gitlab/-/issues/548390
      return this.activeDuoTier === DUO_PRO && !this.hasSelfHostedDapAddOn;
    },
    duoSeatUtilizationDescription() {
      return this.sprintf(this.$options.i18n.duoSeatUtilizationDescriptionText, {
        title: this.duoTitle,
      });
    },
    duoSubscriptionStartDate() {
      return this.$options.i18n.duoSubscriptionStartText.replace(
        '%{startDate}',
        this.formatSubscriptionDate(this.duoAddOnStartDate),
      );
    },
    duoSubscriptionEndDate() {
      return this.$options.i18n.duoSubscriptionEndText.replace(
        '%{endDate}',
        this.formatSubscriptionDate(this.duoAddOnEndDate),
      );
    },
    hasSelfHostedDapAddOn() {
      return this.addOnPurchases.some(({ name }) => name === SELF_HOSTED_DAP);
    },
  },
  methods: {
    handlePurchaseSeats() {
      this.trackEvent(
        'click_purchase_seats_button_group_duo_pro_home_page',
        {
          label: `duo_pro_purchase_seats`,
        },
        'groups:gitlab_duo:show',
      );
    },
    formatSubscriptionDate(dateStr) {
      return formatDate(dateStr, 'mmm dd, yyyy');
    },
  },
};
</script>
<template>
  <gl-card footer-class="gl-bg-transparent gl-border-none gl-flex-end" class="gl-justify-between">
    <template #default>
      <usage-statistics
        :percentage="percentage"
        :total-value="`${totalValue}`"
        :usage-value="`${usageValue}`"
      >
        <template #description>
          <h2 class="gl-m-0 gl-text-lg" data-testid="duo-seat-utilization-info">
            {{ $options.i18n.duoSeatUtilizationTitle }}
          </h2>
        </template>
        <template #additional-info>
          <p class="gl-mb-0 gl-text-subtle" data-testid="duo-seat-utilization-description">
            {{ duoSeatUtilizationDescription }}
          </p>
        </template>
      </usage-statistics>
      <div class="gl-text-subtle" data-testid="duo-seat-utilization-subscription-dates">
        <p class="gl-my-3">
          {{ duoSubscriptionStartDate }}
        </p>
        <p>
          {{ duoSubscriptionEndDate }}
        </p>
      </div>
    </template>
    <template #footer>
      <div data-testid="duo-seat-utilization-action-buttons">
        <gl-button category="primary" variant="confirm" :href="duoSeatUtilizationPath">{{
          $options.i18n.duoAssignSeatsButtonText
        }}</gl-button>
        <gl-button
          v-if="showPurchaseSeatsButton"
          category="primary"
          variant="default"
          :href="addDuoProHref"
          referrerpolicy="no-referrer-when-downgrade"
          @click="handlePurchaseSeats"
          >{{ $options.i18n.duoPurchaseSeatsButtonText }} <gl-icon name="external-link"
        /></gl-button>
      </div>
    </template>
  </gl-card>
</template>
