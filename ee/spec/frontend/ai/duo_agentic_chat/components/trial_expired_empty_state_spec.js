import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from 'ee/ai/constants';
import TrialExpiredEmptyState from 'ee/ai/duo_agentic_chat/components/trial_expired_empty_state.vue';

const buyAddonPathMock = 'https://customers.gitlab.com/subscriptions';

const { bindInternalEventDocument } = useMockInternalEventsTracking();

describe('TrialExpiredEmptyState', () => {
  let wrapper;

  const defaultProps = {
    canBuyAddon: true,
    buyAddonPath: buyAddonPathMock,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(TrialExpiredEmptyState, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findUpgradeButton = () => wrapper.findComponentByTestId('upgrade-button');
  const findEmptyStateText = () => wrapper.findByTestId('empty-state-text');
  const findLearnMoreButton = () => wrapper.findComponentByTestId('learn-more-button');

  it('renders the correct content', () => {
    createComponent({
      canBuyAddon: true,
      buyAddonPath: buyAddonPathMock,
    });

    expect(findEmptyStateText().text()).toBe(
      'Your trial has ended. Repurchase to resume using GitLab Duo Agent Platform.',
    );

    expect(findUpgradeButton().props('href')).toBe(buyAddonPathMock);
    expect(findLearnMoreButton().props('href')).toBe('/help/user/duo_agent_platform/_index.md');
  });

  it('tracks the `view_duo_agentic_trial_expired_empty_state` on mount', () => {
    createComponent({
      canBuyAddon: true,
      buyAddonPath: buyAddonPathMock,
    });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_TRIAL_EXPIRED,
      {},
      undefined,
    );
  });

  it('tracks `click_duo_agentic_trial_expired_upgrade` when upgrade button is clicked', () => {
    createComponent({
      canBuyAddon: true,
      buyAddonPath: buyAddonPathMock,
    });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    findUpgradeButton().vm.$emit('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_TRIAL_EXPIRED_UPGRADE,
      {},
      undefined,
    );
  });

  it('tracks `click_duo_agentic_trial_expired_learn_more` when learn more button is clicked', () => {
    createComponent({
      canBuyAddon: true,
      buyAddonPath: buyAddonPathMock,
    });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    findLearnMoreButton().vm.$emit('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_TRIAL_EXPIRED_LEARN_MORE,
      {},
      undefined,
    );
  });

  describe('upgrade button visibility', () => {
    it('shows upgrade button when canBuyAddon is true and buyAddonPath is present', () => {
      createComponent({
        canBuyAddon: true,
        buyAddonPath: buyAddonPathMock,
      });

      expect(findUpgradeButton().exists()).toBe(true);
    });

    it('hides upgrade button when canBuyAddon is false', () => {
      createComponent({
        canBuyAddon: false,
        buyAddonPath: buyAddonPathMock,
      });

      expect(findUpgradeButton().exists()).toBe(false);
    });

    it('hides upgrade button when buyAddonPath is empty', () => {
      createComponent({
        canBuyAddon: true,
        buyAddonPath: '',
      });

      expect(findUpgradeButton().exists()).toBe(false);
    });
  });
});
