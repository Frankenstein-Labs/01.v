<script>
import { GlButton, GlCard, GlIntersectionObserver, GlLink } from '@gitlab/ui';
import { formatNumber, s__, sprintf } from '~/locale';
import { PROMO_URL } from '~/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import Tracking from '~/tracking';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

export default {
  name: 'DuoAgentPlatformBuyCreditsCard',
  components: {
    GlButton,
    GlCard,
    GlIntersectionObserver,
    GlLink,
    HandRaiseLeadButton,
  },
  mixins: [Tracking.mixin()],
  inject: {
    isSaaS: { default: false },
    gitlabComPurchaseCreditsPath: { default: '' },
    namespaceIsOnTrial: { default: false },
    showSmPurchaseButton: { default: false },
    isSmTrial: { default: false },
    selfManagedPurchaseCreditsPath: { default: '' },
    creditsGeneralizationUi: { default: false },
  },
  props: {
    hasGitlabCredits: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    purchaseCreditsPath() {
      if (this.isSaaS) return this.gitlabComPurchaseCreditsPath;
      if (this.showSmPurchaseButton) return this.selfManagedPurchaseCreditsPath;
      return '';
    },
    showMonthlyCommitmentVariant() {
      if (this.isSaaS) return Boolean(this.gitlabComPurchaseCreditsPath);
      return this.showSmPurchaseButton;
    },
    showGeneralizedCredits() {
      return this.creditsGeneralizationUi && this.showMonthlyCommitmentVariant;
    },
    cardTitle() {
      if (this.showMonthlyCommitmentVariant) {
        return this.$options.i18n.gitlabCreditsTitle;
      }
      return this.$options.i18n.buyCreditsTitle;
    },
    cardSubtitle() {
      if (this.showGeneralizedCredits) {
        return this.$options.i18n.creditsGeneralizedSubtitle;
      }
      if (this.showMonthlyCommitmentVariant) {
        return this.$options.i18n.monthlyCommitmentsSubtitle;
      }
      return this.$options.i18n.agentPlatformSubtitle;
    },
    cardDescription() {
      if (this.showGeneralizedCredits) {
        return sprintf(this.$options.i18n.creditsGeneralizedDescription, {
          minPrice: formatNumber(1),
        });
      }
      if (this.showMonthlyCommitmentVariant) {
        return this.$options.i18n.monthlyCommitmentsDescription;
      }
      return this.$options.i18n.agentPlatformDescription;
    },
    buttonLabel() {
      if (this.hasGitlabCredits) {
        return this.$options.i18n.increaseCredits;
      }
      return this.$options.i18n.purchaseCredits;
    },
    buttonAriaLabel() {
      if (this.hasGitlabCredits) {
        return this.$options.i18n.increaseCreditsAriaLabel;
      }
      return this.$options.i18n.purchaseCreditsAriaLabel;
    },
    learnMorePath() {
      return helpPagePath('subscriptions/gitlab_credits');
    },
    purchaseCreditsEventTracking() {
      const base = this.hasGitlabCredits
        ? 'click_increase_credits_cta'
        : 'click_purchase_credits_cta';

      return this.namespaceIsOnTrial || this.isSmTrial ? `${base}_active_trial` : base;
    },
  },
  methods: {
    trackPageView() {
      this.track('pageview', { label: 'duo_agent_platform_buy_credits_card' });
    },
    trackTalkToSalesClick() {
      this.track('click_button', { label: 'duo_agent_platform_talk_to_sales' });
    },
  },
  i18n: {
    buyCreditsTitle: s__('AiPowered|Buy Credits'),
    gitlabCreditsTitle: s__('AiPowered|GitLab Credits'),
    agentPlatformSubtitle: s__('AiPowered|GitLab Duo Agent Platform'),
    creditsGeneralizedSubtitle: s__('AiPowered|Buy GitLab Credits'),
    creditsGeneralizedDescription: s__(
      'AiPowered|Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $%{minPrice}, with volume discounts.',
    ),
    monthlyCommitmentsSubtitle: s__('AiPowered|Save with monthly commitments'),
    agentPlatformDescription: s__(
      'AiPowered|Orchestrate AI agents across your entire software lifecycle to automate complex workflows, accelerate delivery, and keep your team in flow.',
    ),
    monthlyCommitmentsDescription: s__(
      'AiPowered|Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
    ),
    purchaseCredits: s__('AiPowered|Purchase credits'),
    purchaseCreditsAriaLabel: s__('AiPowered|Purchase credits (opens in new window)'),
    increaseCredits: s__('AiPowered|Increase credits'),
    increaseCreditsAriaLabel: s__('AiPowered|Increase credits (opens in new window)'),
    talkToSales: s__('AiPowered|Talk to Sales'),
    learnMore: s__('AiPowered|Learn more'),
    learnMoreAriaLabel: s__('AiPowered|Learn more about GitLab Credits (opens in new window)'),
  },
  SALES_URL: `${PROMO_URL}/sales/`,
  handRaiseLeadAttributes: {
    variant: 'confirm',
    category: 'primary',
    'data-testid': 'duo-agent-platform-talk-to-sales-action',
  },
  handRaiseLeadCtaTracking: {
    action: 'click_button',
    label: 'duo_agent_platform_buy_credits_card_talk_to_sales',
  },
};
</script>
<template>
  <gl-intersection-observer @appear.once="trackPageView">
    <gl-card header-class="gl-heading-scale-300" class="gl-h-full">
      <template #header>
        <div class="gl-flex gl-items-center gl-justify-between">
          <h3 class="gl-m-0">{{ cardTitle }}</h3>
          <gl-button
            v-if="creditsGeneralizationUi && purchaseCreditsPath"
            :href="purchaseCreditsPath"
            target="_blank"
            rel="noopener noreferrer"
            size="small"
            variant="confirm"
            :aria-label="buttonAriaLabel"
            data-testid="duo-agent-platform-purchase-credits-link"
            :data-event-tracking="purchaseCreditsEventTracking"
          >
            {{ buttonLabel }}
          </gl-button>
        </div>
      </template>
      <template #default>
        <p class="gl-heading-scale-500 gl-mb-0">
          {{ cardSubtitle }}
        </p>
        <p class="gl-mb-0 gl-mt-3">
          {{ cardDescription }}
          <gl-link
            v-if="showGeneralizedCredits"
            :href="learnMorePath"
            target="_blank"
            rel="noopener noreferrer"
            :aria-label="$options.i18n.learnMoreAriaLabel"
            data-testid="duo-agent-platform-learn-more-link"
            data-event-tracking="click_learn_more_link_duo_agent_platform_buy_credits"
          >
            {{ $options.i18n.learnMore }}
          </gl-link>
        </p>
      </template>
      <template #footer>
        <div v-if="!showGeneralizedCredits" data-testid="credits-card-footer">
          <template v-if="purchaseCreditsPath">
            <gl-button
              :href="purchaseCreditsPath"
              target="_blank"
              rel="noopener noreferrer"
              :aria-label="buttonAriaLabel"
              variant="confirm"
              category="primary"
              data-testid="duo-agent-platform-purchase-credits-link"
              :data-event-tracking="purchaseCreditsEventTracking"
            >
              {{ buttonLabel }}
            </gl-button>
            <gl-button
              v-if="isSaaS"
              :href="learnMorePath"
              target="_blank"
              rel="noopener noreferrer"
              :aria-label="$options.i18n.learnMoreAriaLabel"
              data-testid="duo-agent-platform-learn-more-link"
              data-event-tracking="click_learn_more_link_duo_agent_platform_buy_credits"
            >
              {{ $options.i18n.learnMore }}
            </gl-button>
          </template>
          <hand-raise-lead-button
            v-else-if="isSaaS"
            :button-attributes="$options.handRaiseLeadAttributes"
            glm-content="duo_agent_platform_buy_credits"
            :cta-tracking="$options.handRaiseLeadCtaTracking"
            :button-text="$options.i18n.talkToSales"
          />
          <gl-button
            v-else
            :href="$options.SALES_URL"
            target="_blank"
            rel="noopener noreferrer"
            variant="confirm"
            category="primary"
            data-testid="duo-agent-platform-talk-to-sales-link"
            @click="trackTalkToSalesClick"
          >
            {{ $options.i18n.talkToSales }}
          </gl-button>
        </div>
      </template>
    </gl-card>
  </gl-intersection-observer>
</template>
