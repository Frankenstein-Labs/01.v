import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserMenu from '~/super_sidebar/components/user_menu.vue';
import UserMenuUpgradeSubscription from 'ee_component/super_sidebar/components/user_menu_upgrade_subscription.vue';
import { userMenuMockData } from '../mock_data';

describe('UserMenu component', () => {
  let wrapper;

  const GlEmoji = { template: '<img/>' };
  const findUserMenuUpgradeSubscription = () => wrapper.findComponent(UserMenuUpgradeSubscription);

  const createWrapper = (userDataChanges = {}) => {
    wrapper = shallowMountExtended(UserMenu, {
      propsData: {
        data: {
          ...userMenuMockData,
          ...userDataChanges,
        },
      },
      stubs: {
        GlEmoji,
      },
      provide: {
        isImpersonating: false,
        isSaas: false,
      },
    });
  };

  describe('Upgrade subscription component', () => {
    describe('when upgrade_link is not provided', () => {
      it('should not render the upgrade subscription component', () => {
        createWrapper();
        expect(findUserMenuUpgradeSubscription().exists()).toBe(false);
      });
    });

    describe('when upgrade_link is provided', () => {
      const upgradeLink = {
        url: '/groups/test-group/-/billings',
        text: 'Upgrade subscription',
      };

      it('renders the upgrade subscription component with the upgrade_link prop', () => {
        createWrapper({ upgrade_link: upgradeLink });
        expect(findUserMenuUpgradeSubscription().props('upgradeLink')).toEqual(upgradeLink);
      });
    });
  });
});
