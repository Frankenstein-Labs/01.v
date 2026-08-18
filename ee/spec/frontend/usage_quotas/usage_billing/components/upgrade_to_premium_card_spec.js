import { GlButton } from '@gitlab/ui';
import UpgradeToPremiumCard from 'ee/usage_quotas/usage_billing/components/upgrade_to_premium_card.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('UpgradeToPremiumCard', () => {
  let wrapper;

  const createComponent = (provide = {}) => {
    wrapper = mountExtended(UpgradeToPremiumCard, {
      provide: {
        upgradeButtonPath: 'https://subscriptions.example.com',
        creditsGeneralizationUi: false,
        ...provide,
      },
    });
  };

  const findUpgradeButton = () => wrapper.findComponent(GlButton);
  const findCardTitle = () => wrapper.find('.gl-card-header');

  beforeEach(() => {
    createComponent();
  });

  it('renders card title', () => {
    expect(findCardTitle().text()).toBe('Unlock more credits with Premium');
  });

  it('renders message text', () => {
    expect(wrapper.text()).toContain('Upgrade to keep using GitLab Duo Agent Platform');
    expect(wrapper.text()).toContain('access a broad credit allocation');
  });

  it('renders upgrade button', () => {
    expect(findUpgradeButton().props('href')).toBe('https://subscriptions.example.com');
    expect(findUpgradeButton().text()).toBe('Upgrade to Premium');
  });

  describe('tracking', () => {
    useMockInternalEventsTracking();

    it('has correct tracking attributes on upgrade button', () => {
      expect(findUpgradeButton().attributes()).toMatchObject({
        'data-event-tracking': 'click_cta_upgrade_to_premium',
        'data-event-property': 'upgrade_to_premium_card',
      });
    });
  });

  describe('when creditsGeneralizationUi is enabled', () => {
    beforeEach(() => {
      createComponent({ creditsGeneralizationUi: true });
    });

    it('renders new header text', () => {
      expect(findCardTitle().text()).toContain('Do more with Premium');
    });

    it('renders new body text', () => {
      expect(wrapper.text()).toContain(
        'Upgrade to Premium to unlock advanced features and get more out of your GitLab Credits.',
      );
    });

    it('renders upgrade button in the header with small size', () => {
      const headerButton = findCardTitle().findComponent(GlButton);
      expect(headerButton.exists()).toBe(true);
      expect(headerButton.props('size')).toBe('small');
      expect(headerButton.props('href')).toBe('https://subscriptions.example.com');
      expect(headerButton.text()).toBe('Upgrade to Premium');
      expect(headerButton.attributes()).toMatchObject({
        'data-event-tracking': 'click_cta_upgrade_to_premium',
        'data-event-property': 'upgrade_to_premium_card',
      });
    });

    it('does not render footer buttons', () => {
      const footerButtons = wrapper.findAll('.gl-pt-5');
      expect(footerButtons).toHaveLength(0);
    });
  });
});
