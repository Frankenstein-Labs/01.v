import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import UltimatePlanCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/ultimate_plan_card.vue';

describe('UltimatePlanCard', () => {
  let wrapper;

  const defaultProvide = {
    upgradeToUltimateUrl: '/upgrade/ultimate',
    upgradeToUltimateTrackingUrl: '/tracking',
    monthlyCommitmentPurchased: 0,
    trialActive: false,
    eligibleForTrial: true,
    startTrialPath: '/start/trial',
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(UltimatePlanCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findUpgradeButton = () =>
    findButtons().wrappers.find((w) => w.text() === 'Upgrade to Ultimate');
  const findTrialButton = () => findButtons().wrappers.find((w) => w.text() === 'Try for free');
  const findSeeAllFeaturesButton = () =>
    findButtons().wrappers.find((w) => w.text() === 'See all features');
  const findHandRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);

  describe('when monthlyCommitmentPurchased is 0 and no trial', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders upgrade to ultimate button', () => {
      expect(findUpgradeButton().attributes('href')).toBe(defaultProvide.upgradeToUltimateUrl);
      expect(findUpgradeButton().attributes('data-event-tracking')).toBe(
        'click_upgrade_to_ultimate_on_billing_page',
      );
      expect(findUpgradeButton().attributes('referrerpolicy')).toBe('no-referrer-when-downgrade');
    });

    it('renders try for free button', () => {
      expect(findTrialButton().attributes('href')).toBe(defaultProvide.startTrialPath);
    });

    it('does not render HandRaiseLeadButton', () => {
      expect(findHandRaiseLeadButton().exists()).toBe(false);
    });

    it('posts to tracking URL on upgrade button click', () => {
      jest.spyOn(axios, 'post').mockResolvedValue({});

      findUpgradeButton().vm.$emit('click');

      expect(axios.post).toHaveBeenCalledWith(defaultProvide.upgradeToUltimateTrackingUrl);
    });

    it('displays the price', () => {
      expect(wrapper.text()).toContain('$');
      expect(wrapper.text()).toContain('99');
    });

    it('renders see all features link', () => {
      expect(findSeeAllFeaturesButton().attributes('href')).toBe(`${PROMO_URL}/pricing/ultimate`);
    });
  });

  describe('when monthlyCommitmentPurchased is greater than 0', () => {
    beforeEach(() => {
      createComponent({ monthlyCommitmentPurchased: 100 });
    });

    it('does not render upgrade button', () => {
      expect(findUpgradeButton()).toBeUndefined();
    });

    it('renders HandRaiseLeadButton', () => {
      expect(findHandRaiseLeadButton().exists()).toBe(true);
      expect(findHandRaiseLeadButton().props('buttonText')).toBe('Talk to sales');
      expect(findHandRaiseLeadButton().props('glmContent')).toBe('billing-group');
      expect(findHandRaiseLeadButton().props('ctaTracking')).toEqual({
        action: 'click_button',
        property: 'free_with_dap_monthly_commit',
      });
    });
  });

  describe('when trial is active', () => {
    beforeEach(() => {
      createComponent({ trialActive: true });
    });

    it('does not render try for free button', () => {
      expect(findTrialButton()).toBeUndefined();
    });
  });

  describe('when the namespace is not eligible for a trial', () => {
    beforeEach(() => {
      createComponent({ eligibleForTrial: false });
    });

    it('does not render try for free button', () => {
      expect(findTrialButton()).toBeUndefined();
    });
  });
});
