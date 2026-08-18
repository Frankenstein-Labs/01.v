import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgenticAdoptionFunnelEmptyState from 'ee/security_dashboard/components/shared/charts/agentic_adoption_funnel_empty_state.vue';
import AgenticAdoptionFunnelCurve from 'ee/security_dashboard/components/shared/charts/agentic_adoption_funnel_curve.vue';

describe('AgenticAdoptionFunnelEmptyState', () => {
  let wrapper;

  const defaultProps = {
    icon: 'false-positive',
    title: 'False Positive Detection turned off',
    description: 'AI evaluates for false positives, helping to tune the noise to signal ratio',
    disabledDescription: 'Ask someone with the Maintainer or Owner role to turn it on.',
  };

  const manageDuoSettingsPath = '/settings/security';

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(AgenticAdoptionFunnelEmptyState, {
      propsData: { ...defaultProps, ...props },
      provide: { manageDuoSettingsPath, ...provide },
    });
  };

  const findCurve = () => wrapper.findComponent(AgenticAdoptionFunnelCurve);
  const findIcon = () => wrapper.findByTestId('funnel-empty-state-icon').findComponent(GlIcon);
  const findTitle = () => wrapper.findByTestId('funnel-empty-state-heading');
  const findEnableButton = () => wrapper.findByTestId('funnel-empty-state-enable-button');
  const findDisabledDescription = () =>
    wrapper.findByTestId('funnel-empty-state-disabled-description');

  describe('common content', () => {
    beforeEach(() => {
      createComponent({ canEnable: true });
    });

    it('renders the icon', () => {
      expect(findIcon().props('name')).toBe(defaultProps.icon);
    });

    it('renders the title', () => {
      expect(findTitle().text()).toBe(defaultProps.title);
    });

    it('renders the description', () => {
      expect(wrapper.text()).toContain(defaultProps.description);
    });
  });

  describe('decorative curve', () => {
    it('forwards the start and end ratios to the curve', () => {
      createComponent({ startRatio: 0.6, endRatio: 0.2 });

      expect(findCurve().props()).toMatchObject({ startRatio: 0.6, endRatio: 0.2 });
    });

    it('uses the curve defaults when no ratios are provided', () => {
      createComponent();

      expect(findCurve().props()).toMatchObject({ startRatio: 1, endRatio: null });
    });
  });

  describe('when the user can enable the feature', () => {
    beforeEach(() => {
      createComponent({ canEnable: true });
    });

    it('renders an Enable button linking to the Duo settings path', () => {
      const button = findEnableButton();

      expect(button.exists()).toBe(true);
      expect(button.attributes('href')).toBe(manageDuoSettingsPath);
      expect(button.text()).toBe('Enable');
    });

    it('does not render the disabled description', () => {
      expect(findDisabledDescription().exists()).toBe(false);
    });
  });

  describe('when the user cannot enable the feature', () => {
    beforeEach(() => {
      createComponent({
        canEnable: false,
        disabledDescription: 'Ask someone with the Maintainer or Owner role to turn it on.',
      });
    });

    it('does not render the Enable button', () => {
      expect(findEnableButton().exists()).toBe(false);
    });

    it('renders the disabled description with the tanuki-ai icon', () => {
      const disabledDescription = findDisabledDescription();

      expect(disabledDescription.exists()).toBe(true);
      expect(disabledDescription.text()).toContain(
        'Ask someone with the Maintainer or Owner role to turn it on.',
      );
      expect(disabledDescription.findComponent(GlIcon).props('name')).toBe('tanuki-ai');
    });
  });
});
