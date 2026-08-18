import { GlCard } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { PROMO_URL } from '~/constants';
import CreditPurchaseCard from 'ee/admin/subscriptions/show/components/credit_purchase_card.vue';

describe('CreditPurchaseCard', () => {
  let wrapper;

  const purchaseCreditsPath =
    'https://customers.gitlab.com/subscriptions/purchases/gitlab?deployment_type=self_managed&plan_type=gitlab_credits';

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(CreditPurchaseCard, {
      provide: {
        purchaseCreditsPath,
        ...provide,
      },
      stubs: { GlCard },
    });
  };

  const findCtaButton = () => wrapper.findByTestId('credit-purchase-card-cta-button');
  const findExplorePricingButton = () =>
    wrapper.findByTestId('credit-purchase-card-explore-pricing-button');
  const findLearnMoreLink = () => wrapper.findByTestId('credit-purchase-card-learn-more-link');

  beforeEach(() => {
    createComponent();
  });

  it('renders the card title', () => {
    expect(wrapper.text()).toContain('GitLab Credits');
  });

  it('renders the description', () => {
    expect(wrapper.text()).toContain(
      'Purchase monthly credits for your instance and unlock AI capabilities. Volume discounts available.',
    );
  });

  it('renders "Purchase credits" CTA with correct attributes', () => {
    expect(findCtaButton().text()).toBe('Purchase credits');
    expect(findCtaButton().attributes()).toMatchObject({
      href: purchaseCreditsPath,
      'data-event-tracking': 'click_purchase_credits_cta_on_sm_credits_card',
      'data-event-property': 'purchase_credits',
    });
  });

  it('renders "Explore pricing" button with correct attributes', () => {
    expect(findExplorePricingButton().text()).toBe('Explore pricing');
    expect(findExplorePricingButton().attributes()).toMatchObject({
      href: `${PROMO_URL}/pricing/?deployment=self-managed-deployment`,
      target: '_blank',
      'data-event-tracking': 'click_explore_pricing_cta_on_sm_credits_card',
      'data-event-property': 'explore_pricing',
    });
  });

  it('renders "Learn more" link in description with correct attributes', () => {
    expect(findLearnMoreLink().text()).toBe('Learn more');
    expect(findLearnMoreLink().attributes()).toMatchObject({
      href: helpPagePath('subscriptions/gitlab_credits'),
      target: '_blank',
      'data-event-tracking': 'click_learn_more_link_on_sm_credits_card',
      'data-event-property': 'learn_more',
    });
  });

  describe('when purchaseCreditsPath is empty', () => {
    beforeEach(() => {
      createComponent({ purchaseCreditsPath: '' });
    });

    it('does not render the CTA button', () => {
      expect(findCtaButton().exists()).toBe(false);
    });

    it('still renders the explore pricing button', () => {
      expect(findExplorePricingButton().exists()).toBe(true);
    });

    it('still renders the learn more link', () => {
      expect(findLearnMoreLink().exists()).toBe(true);
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    let triggerEvent;
    let trackEventSpy;

    beforeEach(() => {
      ({ triggerEvent, trackEventSpy } = bindInternalEventDocument(wrapper.element));
    });

    it('fires click_purchase_credits_cta_on_sm_credits_card when CTA button is clicked', () => {
      triggerEvent('[data-testid="credit-purchase-card-cta-button"]');

      expect(trackEventSpy).toHaveBeenCalledWith('click_purchase_credits_cta_on_sm_credits_card', {
        property: 'purchase_credits',
      });
    });

    it('fires click_explore_pricing_cta_on_sm_credits_card when explore pricing button is clicked', () => {
      triggerEvent('[data-testid="credit-purchase-card-explore-pricing-button"]');

      expect(trackEventSpy).toHaveBeenCalledWith('click_explore_pricing_cta_on_sm_credits_card', {
        property: 'explore_pricing',
      });
    });

    it('fires click_learn_more_link_on_sm_credits_card when learn more link is clicked', () => {
      triggerEvent('[data-testid="credit-purchase-card-learn-more-link"]');

      expect(trackEventSpy).toHaveBeenCalledWith('click_learn_more_link_on_sm_credits_card', {
        property: 'learn_more',
      });
    });
  });
});
