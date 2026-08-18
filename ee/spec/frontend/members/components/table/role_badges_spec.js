import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleBadges from 'ee/members/components/table/role_badges.vue';

describe('Role badges', () => {
  let wrapper;

  const createWrapper = ({
    member = { canOverride: true, isOverridden: true },
    role = { memberRoleId: 1 },
  } = {}) => {
    wrapper = shallowMountExtended(RoleBadges, {
      propsData: { member, role },
    });
  };

  const findCustomRoleBadge = () => wrapper.findByTestId('custom-role-badge');
  const findOverriddenBadge = () => wrapper.findComponentByTestId('overridden-badge');

  it('does not show component if there are no badges', () => {
    createWrapper({ member: {}, role: {} });

    expect(wrapper.find('*').exists()).toBe(false);
  });

  describe('custom role badge', () => {
    it('shows badge with expected text', () => {
      createWrapper();

      expect(findCustomRoleBadge().text()).toBe('Custom role');
    });

    it.each`
      role                      | isBadgeShown
      ${{ memberRoleId: null }} | ${false}
      ${{ memberRoleId: 1 }}    | ${true}
    `(
      'shows/hides custom role badge when memberRoleId is $role.memberRoleId',
      ({ role, isBadgeShown }) => {
        createWrapper({ role });

        expect(findCustomRoleBadge().exists()).toBe(isBadgeShown);
      },
    );
  });

  describe('overridden badge', () => {
    it('shows badge with expected settings', () => {
      createWrapper();

      expect(findOverriddenBadge().text()).toBe('Overridden');
      expect(findOverriddenBadge().props('variant')).toBe('warning');
    });

    it.each`
      member                                         | isBadgeShown
      ${{ canOverride: false, isOverridden: false }} | ${false}
      ${{ canOverride: false, isOverridden: true }}  | ${false}
      ${{ canOverride: true, isOverridden: false }}  | ${false}
      ${{ canOverride: true, isOverridden: true }}   | ${true}
    `('shows/hides overridden badge when member is $member', ({ member, isBadgeShown }) => {
      createWrapper({ member });

      expect(findOverriddenBadge().exists()).toBe(isBadgeShown);
    });
  });
});
