<script>
import { GlBadge, GlAlert, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { isInFuture } from '~/lib/utils/datetime/date_calculation_utility';
import getAddOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import getCurrentLicense from 'ee/admin/subscriptions/show/graphql/queries/get_current_license.query.graphql';

import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q, DUO_TITLES } from 'ee/constants/duo';
import { DUO_BADGE_TITLES } from 'ee/usage_quotas/code_suggestions/constants';

import {
  currentSubscriptionsEntryName,
  subscriptionHistoryFailedTitle,
  subscriptionHistoryFailedMessage,
  subscriptionActivationFutureDatedNotificationTitle,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
} from 'ee/admin/subscriptions/show/constants';

import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import DuoAmazonQInfoCard from 'ee/ai/settings/components/duo_amazon_q_info_card.vue';
import CodeSuggestionsIntro from './code_suggestions_intro.vue';
import CodeSuggestionsInfoCard from './code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from './code_suggestions_usage_statistics_card.vue';
import CodeSuggestionsUsageLoader from './code_suggestions_usage_loader.vue';

export default {
  name: 'CodeSuggestionsUsage',
  components: {
    ErrorAlert,
    SaasAddOnEligibleUserList,
    SelfManagedAddOnEligibleUserList,
    CodeSuggestionsInfoCard,
    CodeSuggestionsIntro,
    CodeSuggestionsStatisticsCard,
    CodeSuggestionsUsageLoader,
    DuoAmazonQInfoCard,
    GlBadge,
    GlAlert,
    GlSprintf,
    PageHeading,
  },
  inject: {
    isSaaS: {},
    groupId: { default: null },
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  i18n: {
    currentSubscriptionsEntryName,
    subscriptionHistoryFailedTitle,
    subscriptionHistoryFailedMessage,
    subscriptionActivationFutureDatedNotificationTitle,
    subscriptionActivationNotificationText: s__(
      'CodeSuggestions|Your subscription was successfully activated.',
    ),
    subscriptionActivationFutureDatedNotificationMessage: s__(
      'CodeSuggestions|You have successfully added a license that activates on %{date}.',
    ),
  },
  props: {
    title: {
      type: String,
      required: false,
      default: s__('UsageQuota|Seat utilization'),
    },
    subtitle: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      addOnPurchases: undefined,
      addOnPurchasesFetchError: undefined,
      currentSubscription: {},
      activationNotification: null,
      subscriptionFetchError: null,
    };
  },
  computed: {
    addOnPurchase() {
      // Prioritization order: Duo with Amazon Q > Duo Enterprise > Duo Pro > Duo Core
      // For example, a namespace can have a Duo Pro add-on but also a Duo Enterprise trial add-on,
      // and Duo Enterprise would take precedence

      return this.addOnPurchases?.reduce((priorityPurchase, currentPurchase) => {
        if (currentPurchase.name === DUO_AMAZON_Q) return currentPurchase;
        if (priorityPurchase?.name === DUO_AMAZON_Q) return priorityPurchase;
        if (currentPurchase.name === DUO_ENTERPRISE) return currentPurchase;
        if (priorityPurchase?.name === DUO_ENTERPRISE) return priorityPurchase;
        if (currentPurchase.name === DUO_PRO) return currentPurchase;
        if (priorityPurchase?.name === DUO_PRO) return priorityPurchase;

        return currentPurchase;
      }, undefined);
    },
    queryVariables() {
      return {
        namespaceId: this.groupGraphQLId,
      };
    },
    groupGraphQLId() {
      return this.groupId ? convertToGraphQLId(TYPENAME_GROUP, this.groupId) : null;
    },
    totalValue() {
      return this.addOnPurchase?.purchasedQuantity ?? 0;
    },
    usageValue() {
      return this.addOnPurchase?.assignedQuantity ?? 0;
    },
    activeDuoTier() {
      return this.addOnPurchase?.name || DUO_CORE;
    },
    areSeatsAssignable() {
      return this.activeDuoTier === DUO_PRO || this.activeDuoTier === DUO_ENTERPRISE;
    },
    isDuoTierAmazonQ() {
      // Currently, AmazonQ is available for self-managed customers only, so let's add an extra isSaaS check
      return !this.isSaaS && this.activeDuoTier === DUO_AMAZON_Q;
    },
    hasAddOnPurchase() {
      return this.totalValue > 0 && this.usageValue >= 0;
    },
    isLoading() {
      return (
        this.$apollo.queries.addOnPurchases.loading ||
        this.$apollo.queries.currentSubscription.loading
      );
    },
    showTitleAndSubtitle() {
      return !this.isLoading && (this.hasAddOnPurchase || this.addOnPurchasesFetchError);
    },
    shouldShowIntro() {
      return !this.hasAddOnPurchase;
    },
    subtitleText() {
      if (this.subtitle) {
        return this.subtitle;
      }

      const message = this.isSaaS
        ? s__('CodeSuggestions|Manage seat assignments for %{addOnName} within your group.')
        : s__('CodeSuggestions|Manage seat assignments for %{addOnName}.');
      return sprintf(message, { addOnName: this.duoTitle });
    },
    duoTitle() {
      return DUO_TITLES[this.activeDuoTier];
    },
    duoBadgeTitle() {
      return DUO_BADGE_TITLES[this.activeDuoTier];
    },
    activationListeners() {
      return {
        [SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT]: this.displayActivationNotification,
      };
    },
  },
  apollo: {
    addOnPurchases: {
      query: getAddOnPurchasesQuery,
      variables() {
        return this.queryVariables;
      },
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.addOnPurchasesFetchError = errorWithCause;
        this.reportError(error);
      },
    },
    currentSubscription: {
      query: getCurrentLicense,
      skip() {
        return this.isSaaS;
      },
      update({ currentLicense }) {
        return currentLicense || {};
      },
      error() {
        this.subscriptionFetchError = currentSubscriptionsEntryName;
      },
    },
  },
  methods: {
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
    createFutureDatedNotification(startsAt) {
      this.activationNotification = {
        title: this.$options.i18n.subscriptionActivationFutureDatedNotificationTitle,
        message: sprintf(this.$options.i18n.subscriptionActivationFutureDatedNotificationMessage, {
          date: startsAt,
        }),
      };
    },
    displayActivationNotification(license) {
      if (isInFuture(new Date(license.startsAt))) {
        this.createFutureDatedNotification(license.startsAt);
      } else {
        this.activationNotification = {
          title: this.$options.i18n.subscriptionActivationNotificationText,
        };
      }

      this.$apollo.queries.addOnPurchases.refetch();
      this.$apollo.queries.currentSubscription.refetch();
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
  <section>
    <code-suggestions-usage-loader v-if="isLoading" />
    <template v-else>
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

      <template v-if="showTitleAndSubtitle">
        <page-heading>
          <template #heading>
            <span class="gl-flex gl-items-center gl-gap-3">
              <span data-testid="code-suggestions-title">{{ title }}</span>
              <gl-badge v-if="duoBadgeTitle" variant="tier" icon="license">{{
                duoBadgeTitle
              }}</gl-badge>
            </span>
          </template>

          <template #description>
            <span data-testid="code-suggestions-subtitle">
              {{ subtitleText }}
            </span>
          </template>
        </page-heading>

        <slot name="health-check"></slot>
      </template>

      <duo-amazon-q-info-card v-if="isDuoTierAmazonQ" />
      <section v-else-if="hasAddOnPurchase">
        <slot name="duo-card" v-bind="{ totalValue, usageValue, activeDuoTier, addOnPurchases }">
          <template v-if="areSeatsAssignable">
            <section class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
              <code-suggestions-statistics-card
                :total-value="totalValue"
                :usage-value="usageValue"
                :active-duo-tier="activeDuoTier"
              />
              <code-suggestions-info-card
                :group-id="groupId"
                :active-duo-tier="activeDuoTier"
                @error="(errorWithCause) => (addOnPurchasesFetchError = errorWithCause)"
              />
            </section>
            <saas-add-on-eligible-user-list
              v-if="isSaaS"
              :add-on-purchase-id="addOnPurchase.id"
              :active-duo-tier="activeDuoTier"
            />
            <self-managed-add-on-eligible-user-list
              v-else
              :add-on-purchase-id="addOnPurchase.id"
              :active-duo-tier="activeDuoTier"
            />
          </template>
        </slot>
      </section>
      <error-alert
        v-else-if="addOnPurchasesFetchError"
        data-testid="add-on-purchase-fetch-error"
        :error="addOnPurchasesFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        class="gl-mt-5"
      />
      <code-suggestions-intro
        v-else-if="shouldShowIntro"
        :subscription="currentSubscription"
        v-on="activationListeners"
      />
    </template>
  </section>
</template>
