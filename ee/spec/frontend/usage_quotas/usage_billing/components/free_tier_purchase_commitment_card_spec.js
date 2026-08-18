import { GlButton, GlLink } from '@gitlab/ui';
import FreeTierPurchaseCommitmentCard from 'ee/usage_quotas/usage_billing/components/free_tier_purchase_commitment_card.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';

describe('FreeTierPurchaseCommitmentCard', () => {
  let wrapper;

  const purchaseCreditsPath = 'https://customers.gitlab.com/purchase/credits';

  const createComponent = (provide = {}) => {
    wrapper = mountExtended(FreeTierPurchaseCommitmentCard, {
      provide: {
        purchaseCreditsPath,
        creditsGeneralizationUi: false,
        ...provide,
      },
    });
  };

  const findPurchaseButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findLearnMoreButton = () => wrapper.findAllComponents(GlButton).at(1);
  const findCardTitle = () => wrapper.find('.gl-card-header');
  const findLearnMoreLink = () => {
    const links = wrapper.findAllComponents(GlLink);
    return links.wrappers.find((w) => w.attributes('target') === '_blank');
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders card title', () => {
    expect(findCardTitle().text()).toBe('Save on GitLab Credits with monthly commitments');
  });

  it('renders card body', () => {
    expect(wrapper.text()).toContain(
      'Monthly commitments offer significant discounts off list price.',
    );
  });

  it('renders purchase credits button with correct href', () => {
    expect(findPurchaseButton().props('href')).toBe(purchaseCreditsPath);
    expect(findPurchaseButton().props('variant')).toBe('confirm');
    expect(findPurchaseButton().text()).toBe('Purchase credits');
  });

  it('renders learn more button with correct href', () => {
    expect(findLearnMoreButton().props('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
    expect(findLearnMoreButton().props('variant')).toBe('confirm');
    expect(findLearnMoreButton().props('category')).toBe('tertiary');
    expect(findLearnMoreButton().text()).toBe('Learn more');
  });

  describe('tracking', () => {
    it('has correct tracking attributes on purchase credits button', () => {
      expect(findPurchaseButton().attributes()).toMatchObject({
        'data-event-tracking': 'click_purchase_credits_cta_active_trial',
      });
    });

    it('has correct tracking attributes on learn more button', () => {
      expect(findLearnMoreButton().attributes()).toMatchObject({
        'data-event-tracking': 'click_learn_more_link_free_tier_purchase_commitment',
      });
    });
  });

  describe('when creditsGeneralizationUi is enabled', () => {
    beforeEach(() => {
      createComponent({ creditsGeneralizationUi: true });
    });

    it('renders new header text', () => {
      expect(findCardTitle().text()).toContain('Buy GitLab Credits');
    });

    it('renders new body text', () => {
      expect(wrapper.text()).toContain(
        'Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons.',
      );
    });

    it('renders purchase credits button in the header with small size', () => {
      const headerButton = findCardTitle().findComponent(GlButton);
      expect(headerButton.exists()).toBe(true);
      expect(headerButton.props('size')).toBe('small');
      expect(headerButton.props('variant')).toBe('confirm');
      expect(headerButton.props('href')).toBe(purchaseCreditsPath);
      expect(headerButton.text()).toBe('Purchase credits');
    });

    it('renders learn more as inline link', () => {
      const link = findLearnMoreLink();
      expect(link).toBeDefined();
      expect(link.attributes('href')).toBe(helpPagePath('subscriptions/gitlab_credits'));
      expect(link.text()).toBe('Learn more');
    });

    it('does not render footer buttons', () => {
      const footerButtons = wrapper.findAll('.gl-pt-5');
      expect(footerButtons).toHaveLength(0);
    });
  });
});
