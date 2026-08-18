import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { InternalEvents } from '~/tracking';
import SubscriptionExpiredEmptyState from 'ee/ai/duo_agentic_chat/components/subscription_expired_empty_state.vue';

const buyAddonPathMock = 'https://customers.gitlab.com/subscriptions';

describe('SubscriptionExpiredEmptyState', () => {
  let wrapper;
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const findUpgradeButton = () => wrapper.findByTestId('subscription-expired-upgrade-button');
  const findLearnMoreButton = () => wrapper.findByTestId('subscription-expired-learn-more-button');
  const findDescription = () => wrapper.findByTestId('subscription-expired-description');
  const findRoot = () => wrapper.findByTestId('subscription-expired-empty-state');

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SubscriptionExpiredEmptyState, {
      propsData: {
        buyAddonPath: buyAddonPathMock,
        canBuyAddon: true,
        ...props,
      },
      attachTo: document.body,
    });
  };

  it('renders the headline and description with the final cancelled copy', () => {
    createComponent();

    expect(findRoot().text()).toContain(
      'Your GitLab Duo Agent Platform subscription has been cancelled',
    );
    expect(findDescription().text()).toBe(
      'Your subscription has been cancelled. Repurchase to resume using GitLab Duo Agent Platform.',
    );
  });

  it('renders the Repurchase Agent Platform CTA when canBuyAddon and buyAddonPath are present', () => {
    createComponent();

    expect(findUpgradeButton().exists()).toBe(true);
    expect(findUpgradeButton().text()).toBe('Repurchase Agent Platform');
    expect(findUpgradeButton().attributes('href')).toBe(buyAddonPathMock);
  });

  it('renders the Learn more link pointing at the DAP docs', () => {
    createComponent();

    expect(findLearnMoreButton().exists()).toBe(true);
    expect(findLearnMoreButton().attributes('href')).toBe(
      '/help/user/duo_agent_platform/_index.md',
    );
  });

  describe('upgrade button visibility', () => {
    it('hides the upgrade button when canBuyAddon is false', () => {
      createComponent({ canBuyAddon: false });
      expect(findUpgradeButton().exists()).toBe(false);
    });

    it('hides the upgrade button when buyAddonPath is empty', () => {
      createComponent({ buyAddonPath: '' });
      expect(findUpgradeButton().exists()).toBe(false);
    });

    it('still renders the Learn more button when upgrade is hidden', () => {
      createComponent({ canBuyAddon: false });
      expect(findLearnMoreButton().exists()).toBe(true);
    });
  });

  describe('internal event tracking', () => {
    it('binds the view event on the root via data-event-tracking + load flag', () => {
      createComponent();

      expect(findRoot().attributes('data-event-tracking')).toBe(
        'view_duo_agentic_subscription_expired_empty_state',
      );
      expect(findRoot().attributes('data-event-tracking-load')).toBe('true');
    });

    it('binds the upgrade click event via data-event-tracking', () => {
      createComponent();

      expect(findUpgradeButton().attributes('data-event-tracking')).toBe(
        'click_duo_agentic_subscription_expired_upgrade',
      );
    });

    it('binds the learn more click event via data-event-tracking', () => {
      createComponent();

      expect(findLearnMoreButton().attributes('data-event-tracking')).toBe(
        'click_duo_agentic_subscription_expired_learn_more',
      );
    });

    it('fires the view event when load events are scanned', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(document.body);

      InternalEvents.trackInternalLoadEvents(document.body);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'view_duo_agentic_subscription_expired_empty_state',
        {},
      );
    });

    it('fires the upgrade click event on click', () => {
      createComponent();
      const { triggerEvent, trackEventSpy } = bindInternalEventDocument(document.body);

      triggerEvent(findUpgradeButton().element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_duo_agentic_subscription_expired_upgrade',
        {},
      );
    });

    it('fires the learn more click event on click', () => {
      createComponent();
      const { triggerEvent, trackEventSpy } = bindInternalEventDocument(document.body);

      triggerEvent(findLearnMoreButton().element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_duo_agentic_subscription_expired_learn_more',
        {},
      );
    });
  });
});
