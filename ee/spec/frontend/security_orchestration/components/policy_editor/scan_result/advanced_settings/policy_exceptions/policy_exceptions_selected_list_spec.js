import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyExceptionsSelectedList from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selected_list.vue';
import PolicyExceptionsSelectedItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selected_item.vue';

describe('PolicyExceptionsSelectedList', () => {
  let wrapper;

  const mockSelectedExceptions = {
    roles: ['maintainer', 'developer'],
    branches: [
      { source: { pattern: 'main' }, target: { name: 'develop' } },
      { source: { pattern: 'feature/*' }, target: { name: 'main' } },
    ],
    groups: [{ id: 1, name: 'group1' }],
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsSelectedList, {
      propsData: {
        selectedExceptions: mockSelectedExceptions,
        ...props,
      },
    });
  };

  const findSelectedItems = () => wrapper.findAllComponents(PolicyExceptionsSelectedItem);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders selected exception items', () => {
      expect(wrapper.classes()).toContain('gl-mb-2');
      expect(findSelectedItems()).toHaveLength(3);
    });

    it('passes correct props to exception items', () => {
      const items = findSelectedItems();

      expect(items.at(0).props()).toMatchObject({
        count: 2,
        exceptionKey: 'roles',
        title: 'Roles',
      });

      expect(items.at(1).props()).toMatchObject({
        count: 2,
        exceptionKey: 'branches',
        title: 'Source Branch Patterns',
      });

      expect(items.at(2).props()).toMatchObject({
        count: 1,
        exceptionKey: 'groups',
        title: 'Groups',
      });
    });

    it('handles empty selected exceptions', () => {
      createComponent({ selectedExceptions: {} });
      expect(wrapper.classes()).toEqual([]);
      expect(findSelectedItems()).toHaveLength(0);
    });

    it('filters out invalid exception keys', () => {
      createComponent({
        selectedExceptions: {
          roles: ['maintainer'],
          invalidKey: ['value'],
          branches: [],
        },
      });

      const items = findSelectedItems();

      expect(items).toHaveLength(2);
      expect(items.at(0).props('title')).toBe('Roles');
      expect(items.at(1).props('title')).toBe('Source Branch Patterns');
    });
  });

  describe('interactions', () => {
    it('emits edit-item event when item is selected for editing', async () => {
      await findSelectedItems().at(0).vm.$emit('select-item', 'roles');

      expect(wrapper.emitted('edit-item')).toEqual([['roles']]);
    });

    it('emits remove event when item is removed', async () => {
      await findSelectedItems().at(1).vm.$emit('remove', 'branches');

      expect(wrapper.emitted('remove')).toEqual([['branches']]);
    });

    it('handles multiple interactions correctly', async () => {
      await findSelectedItems().at(0).vm.$emit('select-item', 'roles');
      await findSelectedItems().at(1).vm.$emit('remove', 'branches');
      await findSelectedItems().at(2).vm.$emit('select-item', 'groups');

      expect(wrapper.emitted('edit-item')).toEqual([['roles'], ['groups']]);
      expect(wrapper.emitted('remove')).toEqual([['branches']]);
    });
  });
});
