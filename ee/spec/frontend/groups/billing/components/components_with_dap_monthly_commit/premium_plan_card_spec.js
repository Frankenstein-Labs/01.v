import { GlBadge, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import PremiumPlanCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/premium_plan_card.vue';

describe('PremiumPlanCard', () => {
  let wrapper;

  const defaultProvide = {
    upgradeToPremiumUrl: '/upgrade/premium',
    upgradeToPremiumTrackingUrl: '/tracking',
    monthlyCommitmentPurchased: 0,
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(PremiumPlanCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findUpgradeButton = () => wrapper.findComponent(GlButton);
  const findSeeAllFeaturesButton = () =>
    findButtons().wrappers.find((w) => w.text() === 'See all features');
  const findHandRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);

  describe('when monthlyCommitmentPurchased is 0 (highlighted)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the recommended badge', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findBadge().text()).toBe('Recommended');
    });

    it('applies purple background', () => {
      expect(wrapper.find('.gl-bg-feedback-brand').exists()).toBe(true);
    });

    it('renders upgrade to premium button with confirm variant', () => {
      expect(findUpgradeButton().text()).toBe('Upgrade to Premium');
      expect(findUpgradeButton().attributes('href')).toBe(defaultProvide.upgradeToPremiumUrl);
      expect(findUpgradeButton().attributes('variant')).toBe('confirm');
      expect(findUpgradeButton().attributes('data-event-tracking')).toBe(
        'click_upgrade_to_premium_on_billing_page',
      );
      expect(findUpgradeButton().attributes('referrerpolicy')).toBe('no-referrer-when-downgrade');
    });

    it('does not render HandRaiseLeadButton', () => {
      expect(findHandRaiseLeadButton().exists()).toBe(false);
    });

    it('posts to tracking URL on button click', () => {
      jest.spyOn(axios, 'post').mockResolvedValue({});

      findUpgradeButton().vm.$emit('click');

      expect(axios.post).toHaveBeenCalledWith(defaultProvide.upgradeToPremiumTrackingUrl);
    });

    it('displays the plan price', () => {
      expect(wrapper.text()).toContain('$');
      expect(wrapper.text()).toContain('29');
    });

    it('renders see all features link', () => {
      expect(findSeeAllFeaturesButton().attributes('href')).toBe(`${PROMO_URL}/pricing/premium`);
    });
  });

  describe('when monthlyCommitmentPurchased is greater than 0', () => {
    beforeEach(() => {
      createComponent({ monthlyCommitmentPurchased: 100 });
    });

    it('does not display the recommended badge', () => {
      expect(findBadge().exists()).toBe(false);
    });

    it('applies subtle background', () => {
      expect(wrapper.find('.gl-bg-subtle').exists()).toBe(true);
    });

    it('renders HandRaiseLeadButton instead of upgrade button', () => {
      expect(findHandRaiseLeadButton().exists()).toBe(true);
      expect(findHandRaiseLeadButton().props('buttonText')).toBe('Talk to sales');
      expect(findHandRaiseLeadButton().props('glmContent')).toBe('billing-group');
      expect(findHandRaiseLeadButton().props('ctaTracking')).toEqual({
        action: 'click_button',
        property: 'free_with_dap_monthly_commit',
      });
    });
  });
});
