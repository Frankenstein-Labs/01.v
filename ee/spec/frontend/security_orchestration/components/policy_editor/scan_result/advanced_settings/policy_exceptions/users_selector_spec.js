import { shallowMount } from '@vue/test-utils';
import { GlFormGroup } from '@gitlab/ui';
import UsersSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/users_selector.vue';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import { mockUsers } from './mocks';

describe('UsersSelector', () => {
  let wrapper;

  const createWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(UsersSelector, {
      propsData,
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findUserSelect = () => wrapper.findComponent(UserSelect);

  describe('component structure', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the wrapper div with correct classes', () => {
      expect(wrapper.classes()).toEqual(['gl-w-full', 'gl-px-3', 'gl-py-4']);
    });

    it('renders GlFormGroup with correct attributes', () => {
      const formGroup = findFormGroup();

      expect(formGroup.exists()).toBe(true);
      expect(formGroup.attributes('id')).toBe('users-list');
      expect(formGroup.attributes('label-for')).toBe('users-list');
      expect(formGroup.classes()).toContain('gl-w-full');
      expect(formGroup.attributes('label')).toBe('Select user exceptions');
      expect(formGroup.attributes('description')).toBe('Choose which users can bypass this policy');
    });

    it('renders UserSelect component with correct attributes', () => {
      const userSelect = findUserSelect();
      expect(userSelect.exists()).toBe(true);
      expect(userSelect.props('selected')).toEqual([]);
    });
  });

  describe('props handling', () => {
    it('passes empty array as selected when no selectedUsers provided', () => {
      createWrapper();
      expect(findUserSelect().props('selected')).toEqual([]);
    });

    it('converts selectedUsers to user IDs and passes to UserSelect', () => {
      createWrapper({ propsData: { selectedUsers: mockUsers } });
      const expectedIds = mockUsers.map(({ id }) => id);
      expect(findUserSelect().props('selected')).toEqual(expectedIds);
    });

    it('handles empty selectedUsers array', () => {
      createWrapper({ propsData: { selectedUsers: [] } });
      expect(findUserSelect().props('selected')).toEqual([]);
    });

    it('handles selectedUsers with different user objects', () => {
      const customUsers = [
        { id: 'user-100', username: 'test-user-1' },
        { id: 'user-200', username: 'test-user-2' },
      ];
      createWrapper({ propsData: { selectedUsers: customUsers } });
      expect(findUserSelect().props('selected')).toEqual(['user-100', 'user-200']);
    });

    it('handles selectedUsers with missing id properties gracefully', () => {
      const usersWithoutIds = [{ username: 'user1' }, { username: 'user2' }];
      createWrapper({ propsData: { selectedUsers: usersWithoutIds } });
      expect(findUserSelect().props('selected')).toEqual([]);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits set-users event when UserSelect select-items event is triggered', async () => {
      const userSelect = findUserSelect();
      const userApproversData = { user_approvers_ids: ['user-1', 'user-2'] };

      await userSelect.vm.$emit('select-items', userApproversData);

      expect(wrapper.emitted('set-users')).toEqual([[[{ id: 'user-1' }, { id: 'user-2' }]]]);
    });

    it('emits set-users event with empty array when no users are selected', async () => {
      const userSelect = findUserSelect();
      const userApproversData = { user_approvers_ids: [] };

      await userSelect.vm.$emit('select-items', userApproversData);

      expect(wrapper.emitted('set-users')).toEqual([[[]]]);
    });

    it('handles select-items event with undefined user_approvers_ids', async () => {
      const userSelect = findUserSelect();
      const userApproversData = {};

      await userSelect.vm.$emit('select-items', userApproversData);

      expect(wrapper.emitted('set-users')).toEqual([[[]]]);
    });

    it('converts user IDs to user objects correctly', async () => {
      const userSelect = findUserSelect();
      const userApproversData = { user_approvers_ids: ['123', '456', '789'] };

      await userSelect.vm.$emit('select-items', userApproversData);

      expect(wrapper.emitted('set-users')).toEqual([
        [[{ id: '123' }, { id: '456' }, { id: '789' }]],
      ]);
    });

    it('handles multiple select-items events correctly', async () => {
      const userSelect = findUserSelect();

      await userSelect.vm.$emit('select-items', { user_approvers_ids: ['user-1'] });
      await userSelect.vm.$emit('select-items', { user_approvers_ids: ['user-2', 'user-3'] });

      expect(wrapper.emitted('set-users')).toEqual([
        [[{ id: 'user-1' }]],
        [[{ id: 'user-2' }, { id: 'user-3' }]],
      ]);
    });
  });

  describe('internationalization', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays correct label text', () => {
      expect(findFormGroup().attributes('label')).toBe('Select user exceptions');
    });

    it('displays correct description text', () => {
      expect(findFormGroup().attributes('description')).toBe(
        'Choose which users can bypass this policy',
      );
    });
  });
});
