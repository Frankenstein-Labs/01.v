import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PricingInformationApp from 'ee/billings/pricing_information/components/app.vue';

jest.mock('~/locale', () => ({
  ...jest.requireActual('~/locale'),
}));

describe('PricingInformationApp', () => {
  let wrapper;

  const mockGroups = [
    {
      id: 1,
      name: 'Group 1',
      trial_active: false,
      group_billings_href: '/groups/group-1/-/billings',
      upgrade_to_premium_href: '/groups/group-1/-/billings/purchase',
      can_access_duo_chat: true,
      explore_links: {},
    },
    {
      id: 2,
      name: 'Group 2',
      trial_active: true,
      group_billings_href: '/groups/group-2/-/billings',
      upgrade_to_premium_href: '/groups/group-2/-/billings/purchase',
      can_access_duo_chat: false,
      explore_links: {
        mock_explore_link: '/mock/explore/link',
      },
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = mountExtended(PricingInformationApp, {
      propsData: {
        groups: mockGroups,
        dashboardGroupsHref: '/dashboard/groups',
        ...props,
      },
    });
  };

  const findGroupSelect = () => wrapper.findComponentByTestId('group-select');
  const findPlanSectionsContainer = () => wrapper.findByTestId('plan-sections-container');
  const findFreePlanSection = () => wrapper.findByTestId('free-plan-section');
  const findTrialPlanSection = () => wrapper.findByTestId('trial-plan-section');
  const findPremiumPlanSection = () => wrapper.findByTestId('premium-plan-section');
  const findUpgradeTrialSection = () => wrapper.findComponentByTestId('upgrade-trial-section');
  const findManageBillingButton = () => wrapper.findByTestId('manage-billing-button');
  const findUpgradeToPremiumButton = () => wrapper.findByTestId('upgrade-to-premium-button');

  const selectGroup = async (groupId) => {
    const groupSelect = findGroupSelect();
    await groupSelect.vm.$emit('input', groupId);
    await nextTick();
  };

  describe('group selection behavior', () => {
    it('auto-selects single group', () => {
      const singleGroup = [
        {
          id: 1,
          name: 'Only Group',
          trial_active: false,
          group_billings_href: '/groups/only-group/-/billings',
          upgrade_to_premium_href: '/groups/only-group/-/billings/purchase',
        },
      ];

      createComponent({ groups: singleGroup });

      expect(findGroupSelect().props('value')).toBe(1);
      expect(findPlanSectionsContainer().exists()).toBe(true);
    });

    it('shows no group selected by default with multiple groups', () => {
      createComponent();

      expect(findGroupSelect().props('value')).toBeNull();
      expect(findPlanSectionsContainer().exists()).toBe(false);
    });

    it('renders correct group options in select', () => {
      createComponent();

      const expectedOptions = [
        { value: null, text: 'Select group', disabled: true },
        { value: 1, text: 'Group 1' },
        { value: 2, text: 'Group 2' },
      ];

      expect(findGroupSelect().props('options')).toEqual(expectedOptions);
    });
  });

  describe('plan sections display', () => {
    it('shows free plan for groups without trial', async () => {
      createComponent();

      await selectGroup(1);

      expect(findFreePlanSection().exists()).toBe(true);
      expect(findTrialPlanSection().exists()).toBe(false);
      expect(findPremiumPlanSection().exists()).toBe(true);
      expect(findUpgradeTrialSection().exists()).toBe(false);
    });

    it('shows trial upgrade section for groups with active trial', async () => {
      createComponent();

      await selectGroup(2);

      expect(findTrialPlanSection().exists()).toBe(true);
      expect(findFreePlanSection().exists()).toBe(false);
      expect(findPremiumPlanSection().exists()).toBe(false);
      expect(findUpgradeTrialSection().exists()).toBe(true);
    });

    it('passes the correct props to the upgrade trial section', async () => {
      createComponent();

      await selectGroup(2);

      expect(findUpgradeTrialSection().props()).toEqual({
        canAccessDuoChat: false,
        exploreLinks: { mock_explore_link: '/mock/explore/link' },
        groupBillingHref: '/groups/group-2/-/billings',
        groupId: 2,
      });
    });

    it('renders premium plan section when group is selected', async () => {
      createComponent();

      await selectGroup(1);

      expect(findPremiumPlanSection().exists()).toBe(true);
    });
  });

  describe('navigation buttons', () => {
    beforeEach(async () => {
      createComponent();
      await selectGroup(1);
    });

    it('manage billing button has correct href', () => {
      const manageButton = findManageBillingButton();

      expect(manageButton.attributes('href')).toBe(
        '/groups/group-1/-/billings?ref_source=group_billing_page',
      );
      expect(manageButton.text()).toBe('Manage billing');
    });

    it('upgrade to premium button has correct href', () => {
      const upgradeButton = findUpgradeToPremiumButton();

      expect(upgradeButton.attributes('href')).toBe(
        '/groups/group-1/-/billings/purchase?ref_source=group_billing_page',
      );
      expect(upgradeButton.text()).toBe('Upgrade to Premium');
    });

    it('buttons have correct tracking attributes', () => {
      const manageButton = findManageBillingButton();
      const upgradeButton = findUpgradeToPremiumButton();

      expect(manageButton.attributes('data-event-tracking')).toBe('click_button_manage_billing');
      expect(manageButton.attributes('data-event-property')).toBe('1');

      expect(upgradeButton.attributes('data-event-tracking')).toBe(
        'click_button_upgrade_to_premium',
      );
      expect(upgradeButton.attributes('data-event-property')).toBe('1');
    });
  });

  describe('group selection effects', () => {
    beforeEach(() => {
      createComponent();
    });

    it('updates button hrefs when group is selected', async () => {
      await selectGroup(1);

      expect(findManageBillingButton().attributes('href')).toBe(
        '/groups/group-1/-/billings?ref_source=group_billing_page',
      );
      expect(findUpgradeToPremiumButton().attributes('href')).toBe(
        '/groups/group-1/-/billings/purchase?ref_source=group_billing_page',
      );

      await selectGroup(2);

      expect(findManageBillingButton().attributes('href')).toBe(
        '/groups/group-2/-/billings?ref_source=group_billing_page',
      );
      expect(findUpgradeToPremiumButton().attributes('href')).toBe(
        '/groups/group-2/-/billings/purchase?ref_source=group_billing_page',
      );
    });

    it('updates button tracking properties when group is selected', async () => {
      await selectGroup(1);

      expect(findManageBillingButton().attributes('data-event-property')).toBe('1');
      expect(findUpgradeToPremiumButton().attributes('data-event-property')).toBe('1');

      await selectGroup(2);

      expect(findManageBillingButton().attributes('data-event-property')).toBe('2');
      expect(findUpgradeToPremiumButton().attributes('data-event-property')).toBe('2');
    });

    it('renders group IDs in tracking attributes', () => {
      const groupSelect = findGroupSelect();
      expect(groupSelect.attributes('data-event-property')).toBe('[1,2]');
    });
  });

  describe('tracking events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('group select has correct tracking attributes', () => {
      const groupSelect = findGroupSelect();

      expect(groupSelect.attributes('data-event-tracking')).toBe('click_dropdown_group_selection');
      expect(groupSelect.attributes('data-event-property')).toBe('[1,2]');
    });
  });
});
