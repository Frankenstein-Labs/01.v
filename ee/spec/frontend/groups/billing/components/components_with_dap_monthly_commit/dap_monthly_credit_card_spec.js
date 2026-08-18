import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import axios from '~/lib/utils/axios_utils';
import DapMonthlyCreditCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/dap_monthly_credit_card.vue';

describe('DapMonthlyCreditCard', () => {
  let wrapper;

  const defaultProvide = {
    trialActive: false,
    monthlyCommitmentPurchased: 0,
    purchaseCreditsPath: '/purchase/credits',
    purchaseCreditsTrackingUrl: '/track/credits',
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(DapMonthlyCreditCard, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findSubscriptionCredits = () => wrapper.findByTestId('subscription-credits');
  const findTrialIncludedCredits = () => wrapper.findByTestId('trial-included-credits');
  const findCtaButton = () => wrapper.findComponentByTestId('dap-monthly-credit-card-cta-button');
  const findSecondaryButton = () =>
    wrapper.findByTestId('dap-monthly-credit-card-secondary-button');

  describe('when no trial and no monthly commitment (free plan)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the free plan header', () => {
      expect(wrapper.text()).toContain('GitLab Credits');
    });

    it('displays credits count as zero', () => {
      expect(findSubscriptionCredits().text()).toBe('0');
    });

    it('does not display trial included credits', () => {
      expect(findTrialIncludedCredits().exists()).toBe(false);
    });

    it('renders purchase credits CTA', () => {
      expect(findCtaButton().text()).toBe('Purchase credits');
      expect(findCtaButton().attributes('href')).toBe(defaultProvide.purchaseCreditsPath);
    });

    it('displays the description text', () => {
      expect(wrapper.text()).toContain(
        'Purchase monthly credits for your group and unlock AI capabilities. Credits start at $0.95, with volume discounts available.',
      );
    });

    it('does not display the generalized credits description', () => {
      expect(wrapper.text()).not.toContain(
        'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons.',
      );
    });

    it('does not display trial included credit description', () => {
      expect(wrapper.text()).not.toContain('These credits are included in your trial');
    });

    it('renders learn more secondary link', () => {
      expect(findSecondaryButton().text()).toBe('Learn more');
    });

    it('renders secondary link with docs URL', () => {
      expect(findSecondaryButton().attributes('href')).toBe(
        helpPagePath('subscriptions/gitlab_credits'),
      );
    });

    it('sets correct tracking attributes on CTA button', () => {
      expect(findCtaButton().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findCtaButton().attributes('data-event-property')).toBe('purchase_credits');
    });

    it('sets correct tracking attributes on secondary button', () => {
      expect(findSecondaryButton().attributes('data-event-tracking')).toBe(
        'click_secondary_link_on_dap_monthly_credit_card',
      );
      expect(findSecondaryButton().attributes('data-event-property')).toBe('learn_more');
    });

    it('applies subtle background', () => {
      expect(wrapper.classes()).toContain('gl-bg-subtle');
    });

    it('sets CTA button variant to default', () => {
      expect(findCtaButton().attributes('variant')).toBe('default');
    });
  });

  describe('when trial is active without monthly commitment', () => {
    beforeEach(() => {
      createComponent({ trialActive: true });
    });

    it('displays the GitLab Credits header', () => {
      expect(wrapper.text()).toContain('GitLab Credits');
    });

    it('displays trial included credits', () => {
      expect(findTrialIncludedCredits().text()).toBe('24');
    });

    it('displays Credits/user label', () => {
      expect(wrapper.text()).toContain('Credits/user');
    });

    it('displays trial included credit description', () => {
      expect(wrapper.text()).toContain(
        'These credits are included in your trial, and provide access to AI features.',
      );
    });

    it('does not display free plan description', () => {
      expect(wrapper.text()).not.toContain(
        'Purchase monthly credits for your group and unlock AI capabilities.',
      );
    });

    it('does not display subscription credits', () => {
      expect(findSubscriptionCredits().exists()).toBe(false);
    });

    it('renders purchase credits CTA', () => {
      expect(findCtaButton().text()).toBe('Purchase credits');
    });

    it('renders learn more secondary link', () => {
      expect(findSecondaryButton().text()).toBe('Learn more');
    });

    it('renders secondary link with docs URL', () => {
      expect(findSecondaryButton().attributes('href')).toBe(
        helpPagePath('subscriptions/gitlab_credits'),
      );
    });

    it('sets correct tracking attributes on CTA button', () => {
      expect(findCtaButton().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findCtaButton().attributes('data-event-property')).toBe('purchase_credits');
    });

    it('sets correct tracking attributes on secondary button', () => {
      expect(findSecondaryButton().attributes('data-event-tracking')).toBe(
        'click_secondary_link_on_dap_monthly_credit_card',
      );
      expect(findSecondaryButton().attributes('data-event-property')).toBe('learn_more');
    });

    it('applies subtle background', () => {
      expect(wrapper.classes()).toContain('gl-bg-subtle');
    });

    it('sets CTA button variant to default', () => {
      expect(findCtaButton().attributes('variant')).toBe('default');
    });

    describe('when creditsGeneralizationUi is enabled', () => {
      beforeEach(() => {
        createComponent({ trialActive: true, glFeatures: { creditsGeneralizationUi: true } });
      });

      it('displays the updated description text', () => {
        expect(wrapper.text()).toContain(
          'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
        );
      });

      it('does not display the old trial description text', () => {
        expect(wrapper.text()).not.toContain('These credits are included in your trial');
      });
    });

    describe('when creditsGeneralizationUi is disabled', () => {
      beforeEach(() => {
        createComponent({ trialActive: true, glFeatures: { creditsGeneralizationUi: false } });
      });

      it('displays trial included credit description', () => {
        expect(wrapper.text()).toContain(
          'These credits are included in your trial, and provide access to AI features. To maintain access after your trial, purchase monthly credits for your group, starting at $0.95, with volume discounts available.',
        );
      });

      it('does not display the generalized credits description', () => {
        expect(wrapper.text()).not.toContain(
          'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
        );
      });
    });
  });

  describe('when hasDapMonthlyCommitment is true', () => {
    beforeEach(() => {
      createComponent({ monthlyCommitmentPurchased: 100 });
    });

    it('displays the monthly committed pool header', () => {
      expect(wrapper.text()).toContain('GitLab Credits - Monthly committed pool');
    });

    it('displays credits count', () => {
      expect(findSubscriptionCredits().text()).toBe('100');
    });

    it('does not display trial included credits', () => {
      expect(findTrialIncludedCredits().exists()).toBe(false);
    });

    it('displays the description text', () => {
      expect(wrapper.text()).toContain(
        'Your monthly credit commitment is shared across all members of the group.',
      );
    });

    it('renders increase credits CTA', () => {
      expect(findCtaButton().text()).toBe('Increase credits');
    });

    it('renders learn more secondary link', () => {
      expect(findSecondaryButton().text()).toBe('Learn more');
    });

    it('renders secondary link with docs URL', () => {
      expect(findSecondaryButton().attributes('href')).toBe(
        helpPagePath('subscriptions/gitlab_credits'),
      );
    });

    it('sets correct tracking attributes on CTA button', () => {
      expect(findCtaButton().attributes('data-event-tracking')).toBe(
        'click_cta_on_dap_monthly_credit_card',
      );
      expect(findCtaButton().attributes('data-event-property')).toBe('increase_credits');
    });

    it('sets correct tracking attributes on secondary button', () => {
      expect(findSecondaryButton().attributes('data-event-tracking')).toBe(
        'click_secondary_link_on_dap_monthly_credit_card',
      );
      expect(findSecondaryButton().attributes('data-event-property')).toBe('learn_more');
    });

    it('applies purple background', () => {
      expect(wrapper.classes()).toContain('gl-bg-feedback-brand');
    });

    it('sets CTA button variant to confirm', () => {
      expect(findCtaButton().attributes('variant')).toBe('confirm');
    });
  });

  describe('when trial is active with monthly commitment', () => {
    it('displays subscription credits count', () => {
      createComponent({ trialActive: true, monthlyCommitmentPurchased: 50 });

      expect(findSubscriptionCredits().text()).toBe('50');
    });

    it('does not display trial included credits', () => {
      createComponent({ trialActive: true, monthlyCommitmentPurchased: 50 });

      expect(findTrialIncludedCredits().exists()).toBe(false);
    });
  });

  describe('when creditsGeneralizationUi flag is enabled (free plan)', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { creditsGeneralizationUi: true } });
    });

    it('displays the generalized credits description', () => {
      expect(wrapper.text()).toContain(
        'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
      );
    });

    it('does not display the old description', () => {
      expect(wrapper.text()).not.toContain(
        'Purchase monthly credits for your group and unlock AI capabilities.',
      );
    });

    it('still displays the GitLab Credits header', () => {
      expect(wrapper.text()).toContain('GitLab Credits');
    });

    it('still renders purchase credits CTA', () => {
      expect(findCtaButton().text()).toBe('Purchase credits');
    });
  });

  describe('CTA button click tracking', () => {
    beforeEach(() => {
      createComponent();
    });

    it('posts to purchaseCreditsTrackingUrl when CTA button is clicked', () => {
      jest.spyOn(axios, 'post').mockResolvedValue({});

      findCtaButton().vm.$emit('click');

      expect(axios.post).toHaveBeenCalledWith(defaultProvide.purchaseCreditsTrackingUrl);
    });

    it('does not throw when the tracking request fails', () => {
      jest.spyOn(axios, 'post').mockRejectedValue(new Error('Network error'));

      findCtaButton().vm.$emit('click');

      expect(axios.post).toHaveBeenCalledWith(defaultProvide.purchaseCreditsTrackingUrl);
    });
  });
});
