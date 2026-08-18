import BranchPatternException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/branch_pattern_exception.vue';
import RolesExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/roles_exceptions.vue';
import TokensException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/tokens_exception.vue';
import PolicyExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions.vue';
import UsersGroupsExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/users_groups_exceptions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Policy Exceptions', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptions, {
      propsData,
    });
  };

  const findHeader = () => wrapper.findByTestId('header');
  const findSubHeader = () => wrapper.findByTestId('subheader');
  const findBranchPatternException = () => wrapper.findComponent(BranchPatternException);
  const findUsersGroupsExceptions = () => wrapper.findComponent(UsersGroupsExceptions);
  const findRolesExceptions = () => wrapper.findComponent(RolesExceptions);
  const findTokensException = () => wrapper.findComponent(TokensException);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders header', () => {
      expect(findHeader().text()).toBe('Policy Bypass Options');
      expect(findSubHeader().exists()).toBe(false);
      expect(findBranchPatternException().exists()).toBe(false);
      expect(findTokensException().exists()).toBe(false);
    });
  });

  describe('saved exceptions', () => {
    it('renders branch exceptions', () => {
      const branches = [
        { source: { pattern: 'master' }, target: { name: '*test' } },
        { source: { pattern: 'main' }, target: { name: '*test2' } },
      ];
      createComponent({
        propsData: {
          exceptions: {
            branches,
          },
        },
      });

      expect(findBranchPatternException().exists()).toBe(true);
      expect(findBranchPatternException().props('branches')).toEqual(branches);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });

    it('renders tokens exceptions', () => {
      const tokens = [{ id: '1' }, { id: '2' }, { id: '3' }];

      createComponent({
        propsData: {
          exceptions: {
            access_tokens: tokens,
          },
        },
      });

      expect(findTokensException().exists()).toBe(true);
      expect(findTokensException().props('tokens')).toEqual(tokens);
      expect(findSubHeader().text()).toBe('3 bypass configurations defined:');
    });
  });

  describe('users and groups exceptions', () => {
    const users = [{ id: 3 }, { id: 4 }];
    const groups = [{ id: 1 }, { id: 2 }];

    it('renders users exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            users,
          },
        },
      });

      expect(findUsersGroupsExceptions().exists()).toBe(true);
      expect(findUsersGroupsExceptions().props('users')).toEqual(users);
      expect(findUsersGroupsExceptions().props('groups')).toEqual([]);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });

    it('renders groups exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            groups,
          },
        },
      });

      expect(findUsersGroupsExceptions().exists()).toBe(true);
      expect(findUsersGroupsExceptions().props('users')).toEqual([]);
      expect(findUsersGroupsExceptions().props('groups')).toEqual(groups);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });

    it('renders mixed users and groups exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            groups,
            users,
          },
        },
      });

      expect(findUsersGroupsExceptions().props('users')).toEqual(users);
      expect(findUsersGroupsExceptions().props('groups')).toEqual(groups);
      expect(findSubHeader().text()).toBe('4 bypass configurations defined:');
    });
  });

  describe('roles exceptions', () => {
    const roles = ['maintainer', 'developer'];
    const customRoles = [{ id: 1 }, { id: 2 }];

    it('renders roles exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            roles,
          },
        },
      });

      expect(findRolesExceptions().exists()).toBe(true);
      expect(findRolesExceptions().props('roles')).toEqual(roles);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });

    it('renders custom roles exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            custom_roles: customRoles,
          },
        },
      });

      expect(findRolesExceptions().exists()).toBe(true);
      expect(findRolesExceptions().props('customRoles')).toEqual(customRoles);
      expect(findSubHeader().text()).toBe('2 bypass configurations defined:');
    });

    it('renders mixed roles exceptions', () => {
      createComponent({
        propsData: {
          exceptions: {
            roles,
            custom_roles: customRoles,
          },
        },
      });

      expect(findRolesExceptions().exists()).toBe(true);
      expect(findRolesExceptions().props('roles')).toEqual(roles);
      expect(findRolesExceptions().props('customRoles')).toEqual(customRoles);
      expect(findSubHeader().text()).toBe('4 bypass configurations defined:');
    });
  });
});
