<script>
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import {
  subscriptionActivationNotificationText,
  subscriptionActivationFutureDatedNotificationTitle,
  subscriptionActivationFutureDatedNotificationMessage,
  subscriptionHistoryFailedTitle,
  subscriptionHistoryFailedMessage,
  currentSubscriptionsEntryName,
  pastSubscriptionsEntryName,
  futureSubscriptionsEntryName,
  subscriptionMainTitle,
  exportLicenseUsageBtnText,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
  VIEW_ADMIN_SUBSCRIPTION_PAGELOAD,
} from '../constants';
import getCurrentLicense from '../graphql/queries/get_current_license.query.graphql';
import getPastLicenseHistory from '../graphql/queries/get_past_license_history.query.graphql';
import getFutureLicenseHistory from '../graphql/queries/get_future_license_history.query.graphql';
import SubscriptionBreakdown from './subscription_breakdown.vue';
import NoActiveSubscription from './no_active_subscription.vue';

export default {
  name: 'CloudLicenseApp',
  components: {
    GlAlert,
    GlButton,
    GlSprintf,
    PageHeading,
    SubscriptionBreakdown,
    NoActiveSubscription,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['customersPortalUrl'],
  i18n: {
    exportLicenseUsageBtnText,
    subscriptionMainTitle,
    subscriptionHistoryFailedTitle,
    subscriptionHistoryFailedMessage,
  },
  props: {
    licenseUsageFilePath: {
      type: String,
      required: true,
    },
    hasActiveLicense: {
      type: Boolean,
      required: false,
      default: false,
    },
    isAdmin: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    currentSubscription: {
      query: getCurrentLicense,
      update({ currentLicense }) {
        return currentLicense || {};
      },
      error() {
        this.subscriptionFetchError = currentSubscriptionsEntryName;
      },
    },
    pastLicenseHistoryEntries: {
      query: getPastLicenseHistory,
      update({ licenseHistoryEntries }) {
        return licenseHistoryEntries?.nodes || [];
      },
      error() {
        this.subscriptionFetchError = pastSubscriptionsEntryName;
      },
    },
    futureLicenseHistoryEntries: {
      query: getFutureLicenseHistory,
      update({ subscriptionFutureEntries }) {
        return subscriptionFutureEntries?.nodes || [];
      },
      error() {
        this.subscriptionFetchError = futureSubscriptionsEntryName;
      },
    },
  },
  data() {
    return {
      currentSubscription: {},
      pastLicenseHistoryEntries: [],
      futureLicenseHistoryEntries: [],
      activationNotification: null,
      subscriptionFetchError: null,
    };
  },
  computed: {
    hasValidSubscriptionData() {
      return Boolean(Object.keys(this.currentSubscription).length);
    },
    canShowSubscriptionDetails() {
      return this.isAdmin && (this.hasActiveLicense || this.hasValidSubscriptionData);
    },
    subscriptionHistory() {
      return [...this.futureLicenseHistoryEntries, ...this.pastLicenseHistoryEntries];
    },
    activationListeners() {
      return {
        [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT]: this.displayActivationNotification,
      };
    },
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_SUBSCRIPTION_PAGELOAD);
  },
  methods: {
    displayActivationNotification(license) {
      if (isInFuture(new Date(license.startsAt))) {
        this.activationNotification = {
          title: subscriptionActivationFutureDatedNotificationTitle,
          message: sprintf(subscriptionActivationFutureDatedNotificationMessage, {
            date: license.startsAt,
          }),
        };
      } else {
        this.activationNotification = { title: subscriptionActivationNotificationText };
      }
      this.$apollo.queries.currentSubscription.refetch();
      this.$apollo.queries.pastLicenseHistoryEntries.refetch();
      this.$apollo.queries.futureLicenseHistoryEntries.refetch();
    },
    dismissActivationNotification() {
      this.activationNotification = null;
    },
    dismissSubscriptionFetchError() {
      this.subscriptionFetchError = null;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="$options.i18n.subscriptionMainTitle">
      <template #actions>
        <gl-button
          v-if="canShowSubscriptionDetails"
          class="gl-ml-auto"
          data-testid="export-license-usage-btn"
          :href="licenseUsageFilePath"
          >{{ $options.i18n.exportLicenseUsageBtnText }}
        </gl-button>
      </template>
    </page-heading>
    <gl-alert
      v-if="activationNotification"
      variant="success"
      :title="activationNotification.title"
      class="gl-mb-6"
      data-testid="subscription-activation-success-alert"
      @dismiss="dismissActivationNotification"
    >
      {{ activationNotification.message }}
    </gl-alert>
    <gl-alert
      v-if="subscriptionFetchError"
      :title="$options.i18n.subscriptionHistoryFailedTitle"
      variant="danger"
      class="gl-mb-6"
      data-testid="subscription-fetch-error-alert"
      @dismiss="dismissSubscriptionFetchError"
    >
      <gl-sprintf :message="$options.i18n.subscriptionHistoryFailedMessage">
        <template #subscriptionEntryName>
          {{ subscriptionFetchError }}
        </template>
      </gl-sprintf>
    </gl-alert>
    <subscription-breakdown
      v-if="canShowSubscriptionDetails"
      :subscription="currentSubscription"
      :subscription-list="subscriptionHistory"
      v-on="activationListeners"
    />
    <no-active-subscription
      v-else
      :subscription-list="subscriptionHistory"
      v-on="activationListeners"
    />
  </div>
</template>
