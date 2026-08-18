<script>
import { defineAsyncComponent } from 'vue';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { GlButton, GlModalDirective, GlModal } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { createAlert } from '~/alert';
import { logError } from '~/lib/logger';
import { __, sprintf } from '~/locale';
import SubscriptionDetailsHistory from 'jh_else_ee/admin/subscriptions/show/components/subscription_details_history.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import {
  addActivationCode,
  licensedToHeaderText,
  manageSubscription,
  subscriptionDetailsHeaderText,
} from '../constants';
import CreditPurchaseCard from './credit_purchase_card.vue';
import SubscriptionActivationModal from './subscription_activation_modal.vue';
import SubscriptionDetailsCard from './subscription_details_card.vue';
import SubscriptionDetailsUserInfo from './subscription_details_user_info.vue';

export const subscriptionDetailsFields = [
  'id',
  'subscriptionName',
  'plan',
  'lastSync',
  'startsAt',
  'expiresAt',
];
export const licensedToFields = ['name', 'email', 'company'];

export const i18n = Object.freeze({
  addActivationCode,
  manageSubscription,
  licensedToHeaderText,
  subscriptionDetailsHeaderText,
  removeLicense: __('Remove license'),
  removeLicenseConfirmSaaS: sprintf(
    __(
      'This change will remove %{strongOpen}ALL%{strongClose} Premium and Ultimate features for %{strongOpen}ALL%{strongClose} SaaS customers and make tests start failing.',
    ),
    { strongOpen: '<strong>', strongClose: '</strong>' },
    false,
  ),
  removeLicenseConfirm: __('Are you sure you want to remove the license?'),
  removeLicenseButtonLabel: __('Remove license'),
  removeLicenseError: __('Something went wrong while removing the license. Please try again.'),
  cancel: __('Cancel'),
});

export default {
  name: 'SubscriptionBreakdown',
  directives: {
    GlModalDirective,
    SafeHtml,
  },
  components: {
    CreditPurchaseCard,
    GlButton,
    GlModal,
    SubscriptionActivationModal,
    SubscriptionDetailsCard,
    SubscriptionDetailsHistory,
    SubscriptionDetailsUserInfo,
    SubscriptionSyncNotifications: defineAsyncComponent(
      () => import('./subscription_sync_notifications.vue'),
    ),
  },
  mixins: [glListenersMixin],
  inject: ['licenseRemovePath', 'customersPortalUrl'],
  props: {
    subscription: {
      type: Object,
      required: true,
    },
    subscriptionList: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      licensedToFields,
      subscriptionDetailsFields,
      activationModalVisible: false,
    };
  },
  computed: {
    ...mapState(['breakdown']),
    licenseError() {
      return this.breakdown.licenseError;
    },
    hasAsyncActivity() {
      return this.breakdown.hasAsyncActivity;
    },
    canRemoveLicense() {
      return this.licenseRemovePath;
    },
    hasSubscription() {
      return Boolean(Object.keys(this.subscription).length);
    },
    hasSubscriptionHistory() {
      return Boolean(this.subscriptionList.length);
    },
    shouldShowFooter() {
      return this.canRemoveLicense;
    },
    shouldShowNotifications() {
      return this.breakdown.shouldShowNotifications;
    },
    subscriptionHistory() {
      if (!this.hasSubscriptionHistory) return [this.subscription];
      if (!this.hasSubscription) return this.subscriptionList;

      // Only the current license carries `hasGitlabCreditsAddOn`; past history rows cannot
      // surface the credits add-on suffix until the CDot API exposes it per entry.
      // Tracked in #601231.
      return this.subscriptionList.map((entry) =>
        this.subscription.id && entry.id === this.subscription.id
          ? { ...entry, hasGitlabCreditsAddOn: this.subscription.hasGitlabCreditsAddOn }
          : entry,
      );
    },
  },
  watch: {
    licenseError(error) {
      logError(error);
      this.showAlert(i18n.removeLicenseError);
    },
  },
  methods: {
    ...mapActions(['removeLicense']),
    showAlert(errorMsg) {
      createAlert({ message: errorMsg });
    },
  },
  i18n,
  activateSubscriptionModal: {
    id: uniqueId('subscription-activation-modal-'),
  },
  removeLicenseModal: {
    id: uniqueId('remove-license-modal-'),
    title: i18n.removeLicense,
    actionCancel: {
      text: i18n.cancel,
    },
    actionPrimary: {
      text: i18n.removeLicense,
      attributes: { variant: 'danger', 'data-testid': 'confirm-remove-license-button' },
    },
  },
  isDotCom: gon.dot_com,
};
</script>

<template>
  <div>
    <subscription-activation-modal
      v-if="hasSubscription"
      v-model="activationModalVisible"
      :modal-id="$options.activateSubscriptionModal.id"
      v-on="glListeners()"
    />
    <subscription-sync-notifications v-if="shouldShowNotifications" class="gl-mb-4" />

    <div class="gl-flex gl-flex-col gl-gap-5">
      <div class="gl-grid gl-gap-5 @sm/panel:gl-grid-cols-2">
        <subscription-details-card
          :details-fields="subscriptionDetailsFields"
          :header-text="$options.i18n.subscriptionDetailsHeaderText"
          :subscription="subscription"
          data-testid="subscription-details-card"
        >
          <template v-if="shouldShowFooter" #footer>
            <div class="gl-flex gl-flex-wrap gl-items-start gl-justify-between gl-gap-3">
              <div class="gl-flex gl-gap-3">
                <gl-button
                  variant="confirm"
                  :href="customersPortalUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                  data-testid="subscription-manage-subscription-action"
                >
                  {{ $options.i18n.manageSubscription }}
                </gl-button>
                <gl-button
                  v-gl-modal-directive="$options.activateSubscriptionModal.id"
                  data-testid="subscription-activate-subscription-action"
                >
                  {{ $options.i18n.addActivationCode }}
                </gl-button>
              </div>
              <gl-button
                v-gl-modal-directive="$options.removeLicenseModal.id"
                category="tertiary"
                :loading="hasAsyncActivity"
                :title="$options.i18n.removeLicenseButtonLabel"
                :aria-label="$options.i18n.removeLicenseButtonLabel"
                variant="danger"
                data-testid="remove-license-button"
              >
                {{ $options.i18n.removeLicense }}
              </gl-button>
              <gl-modal
                :modal-id="$options.removeLicenseModal.id"
                v-bind="$options.removeLicenseModal"
                @primary="removeLicense"
              >
                <div
                  v-if="$options.isDotCom"
                  v-safe-html="$options.i18n.removeLicenseConfirmSaaS"
                ></div>
                <br />
                <div>{{ $options.i18n.removeLicenseConfirm }}</div>
              </gl-modal>
            </div>
          </template>
        </subscription-details-card>
        <subscription-details-card
          :details-fields="licensedToFields"
          :header-text="$options.i18n.licensedToHeaderText"
          :subscription="subscription"
        />
      </div>
      <credit-purchase-card v-if="subscription.trial" />
      <subscription-details-user-info v-if="hasSubscription" :subscription="subscription" />
      <subscription-details-history
        v-if="hasSubscription"
        :current-subscription-id="subscription.id"
        :subscription-list="subscriptionHistory"
      />
    </div>
  </div>
</template>
