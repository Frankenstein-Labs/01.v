import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import TrialWidgetButtons from 'ee/contextual_sidebar/components/trial_widget_buttons.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('TrialWidgetButton component', () => {
  let wrapper;

  const findLearnAboutFeaturesButton = () => wrapper.findByTestId('learn-about-features-btn');
  const findUpgradeButton = () => wrapper.findByTestId('upgrade-options-btn');

  const provide = {
    trialType: 'duo_enterprise',
    daysRemaining: 40,
    percentageComplete: 33,
    trialDiscoverPagePath: '#discover',
    purchaseNowUrl: '#purchase',
  };

  const createComponent = (providers = {}) => {
    const options = { provide: { ...provide, ...providers } };
    wrapper = shallowMountExtended(TrialWidgetButtons, options);
  };

  const createDeepComponent = (providers = {}) => {
    const options = { provide: { ...provide, ...providers } };
    wrapper = mountExtended(TrialWidgetButtons, options);
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  describe('when trial is active and upgrade threshold is not met', () => {
    it.each(['duo_pro', 'duo_enterprise', 'ultimate_with_dap'])(
      'uses correct learn more text and destination for %s',
      (trialType) => {
        createComponent({ trialType });

        expect(findLearnAboutFeaturesButton().text()).toBe('Learn more');
        expect(findLearnAboutFeaturesButton().attributes('href')).toBe('#discover');
      },
    );
  });

  describe('when on the last day of the trial', () => {
    it('renders the upgrade options text', () => {
      createComponent({ daysRemaining: 1, percentageComplete: 98 });

      expect(findUpgradeButton().text()).toBe('Upgrade');
      expect(findUpgradeButton().attributes('href')).toBe('#purchase');
    });
  });

  describe('when trial has expired or past upgrade threshold', () => {
    it.each([
      ['duo_pro', 0],
      ['duo_pro', 10],
      ['duo_enterprise', -1],
      ['ultimate_with_dap', 1],
    ])('uses correct upgrade text and destination for %s', (trialType, daysRemaining) => {
      createComponent({ trialType, daysRemaining });

      expect(findUpgradeButton().text()).toBe('Upgrade');
      expect(findUpgradeButton().attributes('href')).toBe('#purchase');
    });
  });

  it('for duo enterprise the learn more button should track click event', async () => {
    createDeepComponent({ daysRemaining: 40 });

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    await findLearnAboutFeaturesButton().trigger('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_learn_more_link_on_trial_widget',
      {
        label: 'gitlab_duo_enterprise',
      },
      undefined,
    );
  });

  it('for duo pro the upgrade button should track click event', async () => {
    createDeepComponent({ trialType: 'duo_pro', daysRemaining: -1 });

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    await findUpgradeButton().trigger('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_upgrade_link_on_trial_widget',
      {
        label: 'gitlab_duo_pro',
      },
      undefined,
    );
  });
});
