import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AutoDismissedActionBanner from 'ee/security_orchestration/components/policy_editor/auto_dismissed_action_banner.vue';
import { AUTO_DISMISSED_ACTION_STORAGE_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('AutoDismissedActionBanner', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AutoDismissedActionBanner, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders LocalStorageSync with correct props', () => {
      const localStorageSync = findLocalStorageSync();

      expect(localStorageSync.exists()).toBe(true);
      expect(localStorageSync.props('storageKey')).toBe(AUTO_DISMISSED_ACTION_STORAGE_KEY);
    });

    it('renders alert when not dismissed', () => {
      const alert = findAlert();

      expect(alert.exists()).toBe(true);
      expect(alert.props()).toMatchObject({
        secondaryButtonText: "Don't show again",
        variant: 'tip',
      });
    });

    it('renders formatted banner content with GlSprintf', () => {
      expect(findAlert().text()).toBe(
        'Experimental feature: Try out auto-dismissed actions for vulnerability policy. This feature is expected to be fully available in 18.8.',
      );
    });
  });

  describe('alert visibility', () => {
    it('shows alert when alertDismissed is false', () => {
      createComponent();

      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('dismiss banner', () => {
      it('hides alert when alertDismissed is true', async () => {
        expect(findAlert().exists()).toBe(true);

        await findAlert().vm.$emit('secondaryAction');

        expect(findAlert().exists()).toBe(false);
      });
    });
  });
});
