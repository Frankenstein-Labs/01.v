import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import GroupsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/groups_selector.vue';
import TokensSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/tokens_selector.vue';
import RolesSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/roles_selector.vue';
import ServiceAccountsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_selector.vue';
import UsersSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/users_selector.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';
import {
  ACCOUNTS,
  GROUPS,
  ROLES,
  SOURCE_BRANCH_PATTERNS,
  TOKENS,
  USERS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import {
  mockAccounts,
  mockBranchPatterns,
  mockGroups,
  mockRoles,
  mockTokens,
  mockUsers,
} from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('PolicyExceptionsModal', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsModal, {
      propsData,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findBranchPatternSelector = () => wrapper.findComponent(BranchPatternSelector);
  const findGroupsSelector = () => wrapper.findComponent(GroupsSelector);
  const findTokensSelector = () => wrapper.findComponent(TokensSelector);
  const findUsersSelector = () => wrapper.findComponent(UsersSelector);
  const findPolicyExceptionsSelector = () => wrapper.findComponent(PolicyExceptionsSelector);
  const findRolesSelector = () => wrapper.findComponent(RolesSelector);
  const findSaveButton = () => wrapper.findComponentByTestId('save-button');
  const findModalTitle = () => wrapper.findByTestId('modal-title');
  const findModalSubtitle = () => wrapper.findByTestId('modal-subtitle');
  const findServiceAccountsSelector = () => wrapper.findComponent(ServiceAccountsSelector);

  beforeEach(() => {
    createComponent();
  });

  describe('initial state', () => {
    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.exists()).toBe(true);
      expect(modal.props('size')).toBe('md');
      expect(modal.props('modalId')).toBe('deny-allow-list-modal');

      expect(findPolicyExceptionsSelector().exists()).toBe(true);
    });
  });

  describe('branch patterns', () => {
    it('renders branch pattern selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            branches: mockBranchPatterns,
          },
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      expect(findBranchPatternSelector().exists()).toBe(true);
      expect(findBranchPatternSelector().props('branches')).toEqual(mockBranchPatterns);

      expect(findModalTitle().text()).toBe('Source Branch Patterns');
      expect(findModalSubtitle().text()).toBe(
        'Define branch patterns that can bypass policy requirements. Use an asterisk (*) as a wildcard to match any combination of characters.',
      );
    });

    it('saves selected branch patterns', async () => {
      createComponent({
        propsData: {
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      await findBranchPatternSelector().vm.$emit('set-branches', mockBranchPatterns);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            branches: mockBranchPatterns,
          },
        ],
      ]);
    });
  });

  describe('tokens', () => {
    it('renders tokens selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            access_tokens: mockTokens,
          },
          selectedTab: TOKENS,
        },
      });

      expect(findTokensSelector().exists()).toBe(true);
      expect(findTokensSelector().props('selectedTokens')).toEqual(mockTokens);

      expect(findModalTitle().text()).toBe('Access Token');
      expect(findModalSubtitle().text()).toBe(
        'Select instance group or project level access tokens that can bypass this policy.',
      );
    });

    it('saves selected tokens', async () => {
      createComponent({
        propsData: {
          selectedTab: TOKENS,
        },
      });

      await findTokensSelector().vm.$emit('set-access-tokens', mockTokens);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            access_tokens: mockTokens,
          },
        ],
      ]);
    });
  });

  describe('service accounts', () => {
    it('renders service accounts selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            service_accounts: mockAccounts,
          },
          selectedTab: ACCOUNTS,
        },
      });

      expect(findServiceAccountsSelector().exists()).toBe(true);
      expect(findServiceAccountsSelector().props('selectedAccounts')).toEqual(mockAccounts);

      expect(findModalTitle().text()).toBe('Service Account');
      expect(findModalSubtitle().text()).toBe(
        'Choose which service accounts can bypass this policy.',
      );
    });

    it('saves selected service accounts', async () => {
      createComponent({
        propsData: {
          selectedTab: ACCOUNTS,
        },
      });

      await findServiceAccountsSelector().vm.$emit('set-accounts', mockAccounts);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            service_accounts: mockAccounts,
          },
        ],
      ]);
    });
  });

  describe('groups', () => {
    it('renders groups selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            groups: mockGroups,
          },
          selectedTab: GROUPS,
        },
      });

      expect(findGroupsSelector().exists()).toBe(true);
      expect(findGroupsSelector().props('selectedGroups')).toEqual(mockGroups);

      expect(findModalTitle().text()).toBe('Groups');
      expect(findModalSubtitle().text()).toBe(
        'Select group exceptions. Choose which groups can bypass this policy.',
      );
    });

    it('saves selected groups', async () => {
      createComponent({
        propsData: {
          selectedTab: GROUPS,
        },
      });

      await findGroupsSelector().vm.$emit('set-groups', mockGroups);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            groups: mockGroups,
          },
        ],
      ]);
    });
  });

  describe('users', () => {
    it('renders users selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            users: mockUsers,
          },
          selectedTab: USERS,
        },
      });

      expect(findUsersSelector().exists()).toBe(true);
      expect(findUsersSelector().props('selectedUsers')).toEqual(mockUsers);

      expect(findModalTitle().text()).toBe('Users');
      expect(findModalSubtitle().text()).toBe(
        'Select users exceptions. Choose which users can bypass this policy.',
      );
    });

    it('saves selected users', async () => {
      createComponent({
        propsData: {
          selectedTab: USERS,
        },
      });

      await findUsersSelector().vm.$emit('set-users', mockUsers);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            users: mockUsers,
          },
        ],
      ]);
    });
  });

  describe('roles', () => {
    it('renders roles selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            roles: mockRoles,
            custom_roles: [{ id: 1 }],
          },
          selectedTab: ROLES,
        },
      });

      expect(findRolesSelector().exists()).toBe(true);
      expect(findRolesSelector().props('selectedRoles')).toEqual([...mockRoles, 1]);

      expect(findModalTitle().text()).toBe('Roles');
      expect(findModalSubtitle().text()).toBe(
        'Select role exceptions. Choose which roles can bypass this policy.',
      );
    });

    it('saves selected roles', async () => {
      createComponent({
        propsData: {
          selectedTab: ROLES,
        },
      });

      await findRolesSelector().vm.$emit('set-roles', { roles: mockRoles, custom_roles: [] });

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            roles: mockRoles,
            custom_roles: [],
          },
        ],
      ]);
    });
  });
});
