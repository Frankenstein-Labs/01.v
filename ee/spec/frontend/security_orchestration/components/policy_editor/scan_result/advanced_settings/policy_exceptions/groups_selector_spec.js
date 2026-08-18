import { shallowMount } from '@vue/test-utils';
import { GlFormGroup } from '@gitlab/ui';
import GroupsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/groups_selector.vue';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';

describe('GroupsSelector', () => {
  let wrapper;

  const defaultProvide = {
    assignedPolicyProject: {
      fullPath: 'test-group/test-project',
    },
  };

  const createWrapper = ({ props = {}, provide = defaultProvide } = {}) => {
    wrapper = shallowMount(GroupsSelector, {
      propsData: props,
      provide,
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findScopedGroupsDropdown = () => wrapper.findComponent(ScopedGroupsDropdown);

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
      expect(formGroup.attributes('id')).toBe('groups-list');
      expect(formGroup.attributes('label-for')).toBe('groups-list');
      expect(formGroup.classes()).toContain('gl-w-full');
    });

    it('renders ScopedGroupsDropdown with correct attributes', () => {
      const dropdown = findScopedGroupsDropdown();

      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props('includeDescendants')).toBe(true);
    });
  });

  describe('ScopedGroupsDropdown props', () => {
    it('passes correct fullPath when assignedPolicyProject exists', () => {
      createWrapper();
      const dropdown = findScopedGroupsDropdown();

      expect(dropdown.props('fullPath')).toBe(defaultProvide.assignedPolicyProject.fullPath);
    });

    it('passes empty string as fullPath when assignedPolicyProject is null', () => {
      createWrapper({ provide: { assignedPolicyProject: null } });
      const dropdown = findScopedGroupsDropdown();

      expect(dropdown.props('fullPath')).toBe('');
    });

    it('passes empty string as fullPath when assignedPolicyProject has no fullPath', () => {
      createWrapper({ provide: { assignedPolicyProject: {} } });

      expect(findScopedGroupsDropdown().props('fullPath')).toBe('');
    });

    it('passes empty selected array when no selectedGroups provided', () => {
      createWrapper();

      expect(findScopedGroupsDropdown().props('selected')).toEqual([]);
    });

    it('converts selectedGroups to GraphQL IDs and passes to dropdown', () => {
      createWrapper({ props: { selectedGroups: [{ id: 1 }, { id: 2 }] } });

      expect(findScopedGroupsDropdown().props('selected')).toEqual([
        'gid://gitlab/Group/1',
        'gid://gitlab/Group/2',
      ]);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits set-groups event when dropdown select event is triggered', async () => {
      const dropdown = findScopedGroupsDropdown();
      const newGroups = [{ id: 1 }];

      await dropdown.vm.$emit('select', newGroups);

      expect(wrapper.emitted('set-groups')).toEqual([[[{ id: 1 }]]]);
    });

    it('converts GraphQL IDs back to regular IDs in emitted event', async () => {
      const newGroups = [{ id: 1 }];

      await findScopedGroupsDropdown().vm.$emit('select', newGroups);

      expect(wrapper.emitted('set-groups')[0]).toEqual([[{ id: 1 }]]);
    });

    it('emits empty array when no groups are selected', async () => {
      await findScopedGroupsDropdown().vm.$emit('select', []);

      expect(wrapper.emitted('set-groups')[0]).toEqual([[]]);
    });

    it('handles multiple groups selection correctly', () => {
      const newGroups = [{ id: 1 }, { id: 2 }];

      findScopedGroupsDropdown().vm.$emit('select', newGroups);

      expect(wrapper.emitted('set-groups')[0]).toEqual([[{ id: 1 }, { id: 2 }]]);
    });
  });

  describe('component initialization', () => {
    it('initializes dropdown with converted selectedGroups prop', () => {
      const selectedGroups = [{ id: 5 }, { id: 10 }];

      createWrapper({ props: { selectedGroups } });
      const dropdown = findScopedGroupsDropdown();

      expect(dropdown.props('selected')).toEqual(['gid://gitlab/Group/5', 'gid://gitlab/Group/10']);
    });

    it('handles empty selectedGroups prop correctly', () => {
      createWrapper({ props: { selectedGroups: [] } });

      expect(findScopedGroupsDropdown().props('selected')).toEqual([]);
    });
  });
});
