import { GlModal, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScanProfileLaunchModal, {
  FEATURE_NAME,
} from 'ee/security_configuration/components/scan_profiles/scan_profile_launch_modal.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { visitUrl } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility');

describe('ScanProfileLaunchModal', () => {
  let wrapper;
  let dismissSpy;

  const createComponent = (calloutOptions = {}) => {
    dismissSpy = jest.fn();
    const mockCalloutOptions = {
      dismiss: dismissSpy,
      shouldShowCallout: true,
      ...calloutOptions,
    };

    wrapper = shallowMountExtended(ScanProfileLaunchModal, {
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser(mockCalloutOptions),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findImage = () => wrapper.find('img');

  describe('when callout should be shown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('uses correct feature name for callout dismisser', () => {
      expect(FEATURE_NAME).toBe('security_scanner_profiles_announcement');
    });

    it('renders modal with correct configuration', () => {
      expect(findModal().props()).toMatchObject({
        modalId: 'scanner-profile-launch-modal',
        size: 'md',
        visible: true,
      });
    });

    it('renders primary action button', () => {
      expect(findModal().props('actionPrimary')).toMatchObject({
        text: 'Got it!',
        attributes: {
          variant: 'confirm',
        },
      });
    });

    it('renders secondary action button with correct attributes', () => {
      const actionSecondary = findModal().props('actionSecondary');

      expect(actionSecondary.text).toBe('Learn more');
      expect(actionSecondary.attributes).toMatchObject({
        variant: 'default',
        target: '_blank',
        category: 'secondary',
      });
    });

    it('renders badge with correct text', () => {
      expect(findBadge().props('variant')).toBe('info');
      expect(findBadge().text()).toBe('New feature');
    });

    it('renders modal title', () => {
      expect(wrapper.text()).toContain('Introducing Security Configuration Profiles');
    });

    it('renders modal description', () => {
      expect(wrapper.text()).toContain('Configure once. Apply everywhere.');
      expect(wrapper.text()).toContain(
        'Profiles make it easier to configure and manage your security tools at scale.',
      );
    });

    it('renders image with correct alt text', () => {
      expect(findImage().exists()).toBe(true);
      expect(findImage().attributes('alt')).toBe('Security configuration illustration');
    });
  });

  describe('when callout should not be shown', () => {
    beforeEach(() => {
      createComponent({ shouldShowCallout: false });
    });

    it('does not show the modal', () => {
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('user interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls dismiss when primary button is clicked', () => {
      findModal().vm.$emit('primary');

      expect(dismissSpy).toHaveBeenCalled();
    });

    it('opens documentation in new tab when secondary button is clicked', () => {
      const mockEvent = { preventDefault: jest.fn() };

      findModal().vm.$emit('secondary', mockEvent);

      expect(mockEvent.preventDefault).toHaveBeenCalled();
      expect(visitUrl).toHaveBeenCalled();
    });
  });
});
