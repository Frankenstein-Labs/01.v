<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { minBy } from 'lodash-es';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import UpgradePlanHeader from 'ee/vue_shared/subscription/components/upgrade_plan_header.vue';
import CurrentPlanHeader from 'ee/vue_shared/subscription/components/current_plan_header.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { instanceHasFutureLicenseBanner } from '../constants';
import CreditPurchaseCard from './credit_purchase_card.vue';
import SubscriptionActivationCard from './subscription_activation_card.vue';
import SubscriptionDetailsHistory from './subscription_details_history.vue';

export default {
  name: 'NoActiveSubscription',
  components: {
    CreditPurchaseCard,
    CurrentPlanHeader,
    UpgradePlanHeader,
    GlAlert,
    GlSprintf,
    SubscriptionActivationCard,
    SubscriptionDetailsHistory,
  },
  mixins: [glListenersMixin],
  inject: ['freeTrialPath', 'groupsCount', 'projectsCount', 'usersCount'],
  i18n: {
    instanceHasFutureLicenseBanner,
  },
  props: {
    subscriptionList: {
      type: Array,
      required: true,
    },
  },
  computed: {
    hasItems() {
      return Boolean(this.subscriptionList.length);
    },
    nextFutureDatedLicenseDate() {
      const futureItems = this.subscriptionList.filter((license) =>
        isInFuture(new Date(license.startsAt)),
      );
      const nextFutureDatedItem = minBy(futureItems, (license) => new Date(license.startsAt));
      return nextFutureDatedItem?.startsAt;
    },
    hasFutureDatedLicense() {
      return Boolean(this.nextFutureDatedLicenseDate);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <div class="gl-flex gl-flex-col md:gl-flex-row">
      <current-plan-header
        :seats-in-use="usersCount"
        :total-projects="projectsCount"
        :total-groups="groupsCount"
        :trial-active="false"
        :is-saas="false"
      />

      <upgrade-plan-header
        :trial-active="false"
        :trial-expired="false"
        :start-trial-path="freeTrialPath"
        :can-access-duo-chat="false"
        :is-saas="false"
      />
    </div>

    <credit-purchase-card />

    <subscription-activation-card v-on="glListeners()" />

    <gl-alert
      v-if="hasFutureDatedLicense"
      :title="$options.i18n.instanceHasFutureLicenseBanner.title"
      :dismissible="false"
      class="gl-mt-5"
      variant="info"
      data-testid="subscription-future-licenses-alert"
    >
      <gl-sprintf :message="$options.i18n.instanceHasFutureLicenseBanner.message">
        <template #date>{{ nextFutureDatedLicenseDate }}</template>
      </gl-sprintf>
    </gl-alert>

    <div v-if="hasItems && hasFutureDatedLicense" class="gl-col-12">
      <subscription-details-history :subscription-list="subscriptionList" />
    </div>

    <div v-if="hasItems && !hasFutureDatedLicense" class="gl-col-12">
      <subscription-details-history :subscription-list="subscriptionList" />
    </div>
  </div>
</template>
