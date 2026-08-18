import { GlBadge, GlButton, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import ExpandableGroup from 'ee/security_inventory/components/sidebar/expandable_group.vue';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import { groupWithSubgroups } from '../../mock_data';

jest.mock('ee/security_inventory/components/sidebar/group_list.vue', () => ({
  name: 'GroupList',
}));

describe('ExpandableGroup', () => {
  let wrapper;

  const findIconName = () => wrapper.findComponent(GlIcon).props('name');
  const findSubgroupName = () => wrapper.findByTestId('subgroup-name');
  const findBadgeText = () => wrapper.findComponent(GlBadge).text();
  const findExpandButton = () => wrapper.findComponent(GlButton);
  const findExpandButtonIcon = () => wrapper.findComponent(GlButton).props('icon');
  const subgroupHasHighlightedClass = () =>
    wrapper.findByTestId('subgroup').classes('gl-bg-strong');
  const findGroupList = () => wrapper.findComponent(GroupList);

  const subgroups = groupWithSubgroups.data.group.descendantGroups.edges;

  const createComponent = ({
    group = { ...subgroups[0].node },
    activeFullPath = 'a-group',
    indentation = 0,
    propsData = {},
  } = {}) => {
    wrapper = shallowMountExtended(ExpandableGroup, {
      propsData: {
        group,
        activeFullPath,
        indentation,
        ...propsData,
      },
      stubs: {
        GroupList: stubComponent(GroupList, {
          props: ['activeFullPath', 'groupFullPath', 'indentation'],
        }),
      },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the subgroup icon and name', () => {
      expect(findIconName()).toBe('subgroup');
      expect(findSubgroupName().text()).toBe('Subgroup with projects and subgroups');
    });

    it('shows the project count badge', () => {
      expect(findBadgeText()).toBe('3');
    });

    it('shows the expand button', () => {
      expect(findExpandButtonIcon()).toBe('chevron-right');
    });
  });

  describe('active group highlight', () => {
    it('highlights the active group', () => {
      createComponent({
        group: { fullPath: 'some-group' },
        activeFullPath: 'some-group',
      });

      expect(subgroupHasHighlightedClass()).toBe(true);
    });

    it('does not highlight inactive groups', () => {
      createComponent({
        group: { fullPath: 'some-group' },
        activeFullPath: 'another-group',
      });

      expect(subgroupHasHighlightedClass()).toBe(false);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('on group click, emits select-subgroup event', () => {
      findSubgroupName().trigger('click');

      expect(wrapper.emitted('select-subgroup')).toStrictEqual([
        ['a-group/subgroup-with-projects-and-subgroups'],
      ]);
    });

    it('on expand button click, shows a nested list of subgroups', async () => {
      expect(findExpandButtonIcon()).toBe('chevron-right');
      expect(findGroupList().exists()).toBe(false);

      findExpandButton().vm.$emit('click', { stopPropagation: jest.fn() });
      await waitForPromises();

      expect(findExpandButtonIcon()).toBe('chevron-down');
      expect(findGroupList().exists()).toBe(true);

      expect(findGroupList().props()).toMatchObject({
        activeFullPath: 'a-group',
        groupFullPath: 'a-group/subgroup-with-projects-and-subgroups',
        indentation: 20,
      });
    });
  });

  describe('expanded state', () => {
    const group = { fullPath: 'some-path/some-group', descendantGroupsCount: 1 };

    it.each(['another-group', 'some-path/some-group', ''])(
      'defaults to false when the active group is not a subgroup of this group',
      async (activeFullPath) => {
        createComponent({
          group,
          activeFullPath,
        });
        await nextTick();

        expect(findExpandButtonIcon()).toBe('chevron-right');
      },
    );

    it.each(['some-path/some-group/subgroup', 'some-path/some-group/another-subgroup'])(
      'defaults to true when this group contains the active group',
      async (activeFullPath) => {
        createComponent({
          group,
          activeFullPath,
        });
        await nextTick();

        expect(findExpandButtonIcon()).toBe('chevron-down');
      },
    );

    it('auto-expands when navigating to a subgroup', async () => {
      createComponent({
        group,
        activeFullPath: 'some-path/some-group',
      });
      await nextTick();

      expect(findExpandButtonIcon()).toBe('chevron-right');

      wrapper.setProps({
        activeFullPath: 'some-path/some-group/a-subgroup',
      });
      await nextTick();

      expect(findExpandButtonIcon()).toBe('chevron-down');
    });
  });

  describe('when search is active', () => {
    beforeEach(() => {
      createComponent({ propsData: { hasSearch: true } });
    });

    it('does not render the expand button', () => {
      expect(findExpandButton().exists()).toBe(false);
    });

    it('does not render the group list', () => {
      expect(findGroupList().exists()).toBe(false);
    });
  });
});
