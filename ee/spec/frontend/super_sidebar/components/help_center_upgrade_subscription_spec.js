import { GlNavItem } from '@gitlab/ui';
import HelpCenterUpgradeSubscription from 'ee/super_sidebar/components/help_center_upgrade_subscription.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';

describe('HelpCenterUpgradeSubscription component', () => {
  let wrapper;

  const createWrapper = (provide = {}) => {
    wrapper = mountExtended(HelpCenterUpgradeSubscription, {
      propsData: {
        upgradeLink: '/groups/my-group/-/billings',
      },
      provide: {
        isIconOnly: false,
        ...provide,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findUpgradeButton = () => wrapper.findComponent(GlNavItem);

  describe('upgrade button attributes', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has correct href', () => {
      expect(findUpgradeButton().attributes('href')).toBe('/groups/my-group/-/billings');
    });

    it('has correct tracking attributes', () => {
      const button = findUpgradeButton();
      expect(button.exists()).toBe(true);
      expect(button.attributes('data-track-property')).toBe('nav_upgrade_subscription');
      expect(button.attributes('data-track-action')).toBe('click_button');
      expect(button.attributes('data-track-label')).toBe('upgrade_subscription');
    });
  });

  describe('in icon-only mode', () => {
    beforeEach(() => {
      createWrapper({ isIconOnly: true });
    });

    it('binds isIconOnly prop on GlNavItem', () => {
      expect(wrapper.findComponent(GlNavItem).props('isIconOnly')).toBe(true);
    });
  });
});
