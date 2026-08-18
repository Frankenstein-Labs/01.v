<script>
import { GlLink, GlButton, GlModalDirective, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import {
  addSeatsText,
  EXPLORE_PAID_PLANS_CLICKED,
  seatsOwedHelpText,
  seatsOwedLink,
  seatsOwedText,
  seatsUsedHelpText,
  seatsUsedLink,
  seatsUsedText,
} from 'ee/usage_quotas/seats/constants';
import Tracking from '~/tracking';
import { mergeUrlParams, visitUrl } from '~/lib/utils/url_utility';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'StatisticsSeatsCard',
  components: { GlLink, GlButton, LimitedAccessModal, GlSkeletonLoader, HelpIcon },
  directives: {
    GlModalDirective,
  },
  helpLinks: {
    seatsUsedLink,
    seatsOwedLink,
  },
  i18n: {
    seatsUsedText,
    seatsUsedHelpText,
    seatsOwedText,
    seatsOwedHelpText,
    addSeatsText,
    explorePlansText: s__('Billing|Explore plans'),
  },
  mixins: [Tracking.mixin()],
  inject: ['explorePlansPath', 'namespaceId'],
  props: {
    seatsUsed: {
      type: Number,
      required: false,
      default: null,
    },
    seatsOwed: {
      type: Number,
      required: false,
      default: null,
    },
    purchaseButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    hasFreePlan: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      subscriptionPermissions: null,
      showLimitedAccessModal: false,
    };
  },
  computed: {
    hasLimitedAccess() {
      return LIMITED_ACCESS_KEYS.includes(this.permissionReason);
    },
    shouldRenderSeatsUsedBlock() {
      return this.seatsUsed !== null;
    },
    shouldRenderSeatsOwedBlock() {
      return this.seatsOwed !== null;
    },
    canAddSeats() {
      if (this.hasFreePlan) {
        return false;
      }
      return this.subscriptionPermissions?.canAddSeats ?? true;
    },
    permissionReason() {
      return this.subscriptionPermissions?.reason;
    },
    shouldShowModal() {
      return !this.canAddSeats && this.hasLimitedAccess;
    },
    shouldShowAddSeatsButton() {
      if (this.isLoading || !this.purchaseButtonLink) {
        return false;
      }
      return this.canAddSeats || this.hasLimitedAccess;
    },
    shouldShowExplorePlansButton() {
      if (this.isLoading) {
        return false;
      }
      return this.hasFreePlan;
    },
    isLoading() {
      return this.$apollo.loading;
    },
    // ref_source tracks navigation context for CDOT conversion attribution
    purchaseButtonLinkWithRefSource() {
      return (
        this.purchaseButtonLink &&
        mergeUrlParams({ ref_source: 'group_seat_usage_page' }, this.purchaseButtonLink)
      );
    },
  },
  apollo: {
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update: (data) => ({
        ...data.subscription,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error: (error) => {
        const { networkError } = error;
        if (networkError?.result?.errors.length) {
          networkError?.result?.errors.forEach(({ message }) => Sentry.captureException(message));
        }
        Sentry.captureException(error);
      },
    },
  },
  methods: {
    handleAddSeats() {
      if (this.shouldShowModal) {
        this.showLimitedAccessModal = true;
        return;
      }

      this.trackAddSeats();
      visitUrl(this.purchaseButtonLinkWithRefSource);
    },
    trackAddSeats() {
      this.track('click_button', { label: 'add_seats_saas', property: 'usage_quotas_page' });
    },
    trackExplorePlans() {
      this.track('click_button', { label: EXPLORE_PAID_PLANS_CLICKED });
    },
  },
};
</script>

<template>
  <div class="gl-border gl-flex gl-rounded-base gl-border-section gl-bg-section gl-p-5">
    <gl-skeleton-loader v-if="isLoading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <div v-else class="gl-grow">
      <h2 v-if="shouldRenderSeatsUsedBlock" class="gl-heading-2 gl-mb-3" data-testid="seats-used">
        <span class="gl-relative gl-top-1">
          {{ seatsUsed }}
        </span>
        <span class="gl-text-lg gl-font-normal">
          {{ $options.i18n.seatsUsedText }}
        </span>
        <gl-link
          :href="$options.helpLinks.seatsUsedLink"
          :aria-label="$options.i18n.seatsUsedHelpText"
          class="gl-relative gl-ml-2"
        >
          <help-icon />
        </gl-link>
      </h2>
      <h2 v-if="shouldRenderSeatsOwedBlock" class="gl-heading-2 gl-mb-0" data-testid="seats-owed">
        <span class="gl-relative gl-top-1">
          {{ seatsOwed }}
        </span>
        <span class="gl-text-lg gl-font-normal">
          {{ $options.i18n.seatsOwedText }}
        </span>
        <gl-link
          :href="$options.helpLinks.seatsOwedLink"
          :aria-label="$options.i18n.seatsOwedHelpText"
          class="gl-relative gl-ml-2"
        >
          <help-icon />
        </gl-link>
      </h2>
    </div>
    <gl-button
      v-if="shouldShowAddSeatsButton"
      v-gl-modal-directive="'limited-access-modal-id'"
      category="primary"
      target="_blank"
      variant="confirm"
      class="gl-ml-3 gl-self-start"
      data-testid="purchase-button"
      @click="handleAddSeats"
    >
      {{ $options.i18n.addSeatsText }}
    </gl-button>
    <gl-button
      v-if="shouldShowExplorePlansButton"
      :href="explorePlansPath"
      category="primary"
      target="_blank"
      variant="confirm"
      class="gl-ml-3 gl-self-start"
      data-testid="explore-plans"
      @click="trackExplorePlans"
    >
      {{ $options.i18n.explorePlansText }}
    </gl-button>
    <limited-access-modal
      v-if="shouldShowModal"
      v-model="showLimitedAccessModal"
      :limited-access-reason="permissionReason"
    />
  </div>
</template>
