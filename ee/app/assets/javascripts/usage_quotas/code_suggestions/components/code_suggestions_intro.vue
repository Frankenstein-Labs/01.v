<script>
import {
  GlEmptyState,
  GlLink,
  GlSprintf,
  GlButton,
  GlIntersectionObserver,
  GlAlert,
  GlModalDirective,
} from '@gitlab/ui';

import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import emptyGeoSvgUrl from '@gitlab/svgs/dist/illustrations/empty-state/empty-geo-md.svg?url';
import { uniqueId } from 'lodash-es';
import { __, s__ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import {
  codeSuggestionsLearnMoreLink,
  VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD,
} from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import SubscriptionActivationModal from 'ee/admin/subscriptions/show/components/subscription_activation_modal.vue';
import { addActivationCode, subscriptionTypes } from 'ee/admin/subscriptions/show/constants';
import Tracking, { InternalEvents } from '~/tracking';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'CodeSuggestionsIntro',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    addActivationCode,
    purchaseSeats: __('Purchase seats'),
    buySubscription: __('Buy subscription'),
    trial: __('Start a trial'),
    description: s__(
      'CodeSuggestions|Enhance your coding experience with intelligent recommendations. %{linkStart}GitLab Duo%{linkEnd} offers features that use generative AI to suggest code.',
    ),
    descriptionLegacySubscription: s__(
      'CodeSuggestions|%{linkStart}GitLab Duo%{linkEnd} is only available to instances with a synchronized subscription. Add an activation code to synchronize your subscription.',
    ),
    postTrialForFreeNamespaceDescription: s__(
      "CodeSuggestions|Before you can buy GitLab Duo seats, you'll need a Premium or Ultimate subscription.",
    ),
    postTrialAlertTitle: s__('CodeSuggestions|Your GitLab Duo Pro trial has expired'),
    postTrialAlertBody: s__(
      "CodeSuggestions|To buy GitLab Duo seats and regain access, you'll need a Premium or Ultimate subscription.",
    ),
    title: s__('CodeSuggestions|Introducing GitLab Duo'),
    titleLegacySubscription: s__('CodeSuggestions|Subscription not synchronized'),
  },
  directives: {
    GlModalDirective,
    SafeHtml,
  },
  components: {
    HandRaiseLeadButton,
    GlEmptyState,
    GlLink,
    GlSprintf,
    GlButton,
    GlIntersectionObserver,
    GlAlert,
    SubscriptionActivationModal,
  },
  mixins: [Tracking.mixin(), InternalEvents.mixin(), glListenersMixin],
  inject: {
    isSaaS: { default: true },
    duoProTrialHref: { default: null },
    addDuoProHref: { default: null },
    handRaiseLeadData: { default: {} },
    isFreeNamespace: { default: false },
    duoProActiveTrialEndDate: { default: null },
    buySubscriptionPath: { default: null },
  },
  props: {
    subscription: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isAlertDismissed: false,
      activationModalVisible: false,
    };
  },
  computed: {
    hasSubscription() {
      return Boolean(Object.keys(this.subscription).length);
    },
    purchaseSeatsBtnCategory() {
      return this.duoProTrialHref ? 'secondary' : 'primary';
    },
    showPostTrialForFreeNamespace() {
      return (
        this.isFreeNamespace &&
        !this.duoProActiveTrialEndDate &&
        !this.isSelfManagedLegacySubscription
      );
    },
    isSelfManagedLegacySubscription() {
      return (
        !this.isSaaS &&
        this.hasSubscription &&
        this.subscription.type === subscriptionTypes.LEGACY_LICENSE
      );
    },
    emptyState() {
      if (this.isSelfManagedLegacySubscription) {
        return {
          svgPath: emptyGeoSvgUrl,
          title: this.$options.i18n.titleLegacySubscription,
          description: this.$options.i18n.descriptionLegacySubscription,
        };
      }

      return {
        svgPath: emptyStateSvgUrl,
        title: this.$options.i18n.title,
        description: this.$options.i18n.description,
      };
    },
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD);
  },
  methods: {
    trackPageView() {
      if (this.duoProTrialHref) {
        this.track('pageview', { label: 'duo_pro_add_on_tab_pre_trial' });
      } else if (this.showPostTrialForFreeNamespace) {
        this.track('pageview', { label: 'duo_pro_add_on_tab_expired_trial' });
      }
    },
    trackTrialClick() {
      this.track('click_button', { label: 'duo_pro_start_trial' });
    },
    trackPurchaseSeatsClick() {
      this.track('click_button', { label: 'duo_pro_purchase_seats' });
    },
    trackLearnMoreClick() {
      this.track('click_link', { label: 'duo_pro_marketing_page' });
    },
    trackBuySubscription() {
      this.track('click_button', { label: 'duo_pro_buy_subscription' });
    },
  },
  apolloProvider,
  activateSubscriptionModal: {
    id: uniqueId('subscription-activation-modal-'),
  },
};
</script>
<template>
  <gl-intersection-observer @appear="trackPageView">
    <subscription-activation-modal
      v-if="isSelfManagedLegacySubscription"
      v-model="activationModalVisible"
      :modal-id="$options.activateSubscriptionModal.id"
      v-on="glListeners()"
    />

    <gl-alert
      v-if="showPostTrialForFreeNamespace && !isAlertDismissed"
      class="gl-mb-9"
      variant="danger"
      :title="$options.i18n.postTrialAlertTitle"
      data-testid="duo-pro-post-trial-alert"
      @dismiss="isAlertDismissed = true"
    >
      {{ $options.i18n.postTrialAlertBody }}
    </gl-alert>

    <gl-empty-state :svg-path="emptyState.svgPath" :svg-height="72">
      <template #title>
        <h1 class="h4 gl-text-size-h-display gl-leading-36">{{ emptyState.title }}</h1>
      </template>
      <template #description>
        <p v-if="showPostTrialForFreeNamespace" class="gl-max-w-48">
          {{ $options.i18n.postTrialForFreeNamespaceDescription }}
        </p>

        <gl-sprintf v-else :message="emptyState.description">
          <template #link="{ content }">
            <gl-link
              :href="$options.helpLinks.codeSuggestionsLearnMoreLink"
              target="_blank"
              class="gl-underline"
              data-testid="duo-pro-learn-more-link"
              @click="trackLearnMoreClick"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </template>
      <template #actions>
        <gl-button
          v-if="duoProTrialHref"
          :href="duoProTrialHref"
          variant="confirm"
          category="primary"
          class="gl-w-full @sm/panel:gl-w-auto"
          data-testid="duo-pro-start-trial-btn"
          @click="trackTrialClick"
        >
          {{ $options.i18n.trial }}
        </gl-button>

        <gl-button
          v-if="isSelfManagedLegacySubscription"
          v-gl-modal-directive="$options.activateSubscriptionModal.id"
          variant="confirm"
          category="primary"
          class="gl-mt-3 gl-w-full @sm/panel:gl-ml-3 @sm/panel:gl-mt-0 @sm/panel:gl-w-auto"
          data-testid="code-suggestions-activate-subscription-action"
        >
          {{ $options.i18n.addActivationCode }}
        </gl-button>

        <gl-button
          v-else-if="showPostTrialForFreeNamespace"
          :href="buySubscriptionPath"
          variant="confirm"
          class="gl-w-full @sm/panel:gl-w-auto"
          data-testid="duo-pro-buy-subscription-btn"
          @click="trackBuySubscription"
        >
          {{ $options.i18n.buySubscription }}
        </gl-button>

        <gl-button
          v-else
          :href="addDuoProHref"
          variant="confirm"
          :category="purchaseSeatsBtnCategory"
          class="gl-mt-3 gl-w-full @sm/panel:gl-ml-3 @sm/panel:gl-mt-0 @sm/panel:gl-w-auto"
          data-testid="duo-pro-purchase-seats-btn"
          referrerpolicy="no-referrer-when-downgrade"
          @click="trackPurchaseSeatsClick"
        >
          {{ $options.i18n.purchaseSeats }}
        </gl-button>

        <hand-raise-lead-button
          v-if="isSaaS"
          :button-attributes="handRaiseLeadData.buttonAttributes"
          :glm-content="handRaiseLeadData.glmContent"
          :product-interaction="handRaiseLeadData.productInteraction"
          :cta-tracking="handRaiseLeadData.ctaTracking"
        />
      </template>
    </gl-empty-state>
  </gl-intersection-observer>
</template>
