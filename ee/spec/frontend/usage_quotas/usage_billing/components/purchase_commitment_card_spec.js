import { GlButton, GlSprintf } from '@gitlab/ui';
import PurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/purchase_commitment_card.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PurchaseCommitmentCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = (propsData = {}, provide = {}) => {
    wrapper = shallowMountExtended(PurchaseCommitmentCard, {
      propsData: {
        purchaseCreditsUrl: 'https://customers.gitlab.com/purchase/credits',
        hasCommitment: false,
        ...propsData,
      },
      provide: {
        isSaas: true,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('with monthly commitment', () => {
    beforeEach(() => {
      createComponent({ hasCommitment: true });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Increase monthly credit commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        'Increase your commitment to unlock higher discounts. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders call to action buttons', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe(
        'https://customers.gitlab.com/purchase/credits?ref_source=group_usage_billing_page',
      );
      expect(button.text()).toBe('Increase commitment');

      const handRaiseButton = wrapper.findComponent(HandRaiseLeadButton);

      expect(handRaiseButton.props('glmContent')).toBe('usage_billing_purchase_credits');
      expect(handRaiseButton.props('buttonText')).toBe('Contact sales');
    });

    describe('when isSaas is false', () => {
      beforeEach(() => {
        createComponent({ hasCommitment: true }, { isSaas: false });
      });

      it('does not render contact sales button', () => {
        expect(wrapper.findComponent(GlButton).text()).toBe('Increase commitment');
        expect(wrapper.findComponent(HandRaiseLeadButton).exists()).toBe(false);
      });
    });

    describe('when isPaidBasePlan is true', () => {
      beforeEach(() => {
        createComponent({ hasCommitment: true }, { isPaidBasePlan: true });
      });

      it('does not render contact sales button', () => {
        expect(wrapper.findComponent(GlButton).text()).toBe('Increase commitment');
        expect(wrapper.findComponent(HandRaiseLeadButton).exists()).toBe(false);
      });
    });
  });

  describe('without monthly commitment', () => {
    beforeEach(() => {
      createComponent({ hasCommitment: false });
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Save on GitLab Credits with monthly commitment');
    });

    it('renders card body', () => {
      expect(wrapper.find('p').text()).toMatchInterpolatedText(
        'Monthly commitments offer significant discounts off list price. Share GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about GitLab Credit pricing.',
      );
    });

    it('renders call to action button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.props('href')).toBe(
        'https://customers.gitlab.com/purchase/credits?ref_source=group_usage_billing_page',
      );
      expect(button.text()).toBe('Purchase monthly commitment');
    });
  });
});
