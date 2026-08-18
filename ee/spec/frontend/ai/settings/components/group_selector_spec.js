import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlCollapsibleListbox, GlButton, GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import GroupSelector from 'ee/ai/settings/components/group_selector.vue';
import searchGroups from 'ee/ai/graphql/search_groups.query.graphql';

Vue.use(VueApollo);

const mockGroup1 = {
  id: 'gid://gitlab/Group/1',
  name: 'Group A',
  fullPath: 'group-a',
};

const mockGroup2 = {
  id: 'gid://gitlab/Group/2',
  name: 'Group B',
  fullPath: 'group-b',
};

const mockGroup3 = {
  id: 'gid://gitlab/Group/3',
  name: 'Group C',
  fullPath: 'group-c',
};

const mockGroupsResponse = {
  data: {
    groups: {
      nodes: [mockGroup1, mockGroup2, mockGroup3],
    },
  },
};

const searchGroupsSuccessHandler = jest.fn().mockResolvedValue(mockGroupsResponse);

describe('GroupSelector', () => {
  let wrapper;

  const findButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateGroupLink = () => wrapper.findComponent(GlLink);

  const createComponent = ({
    searchGroupsHandler = searchGroupsSuccessHandler,
    provide = {},
    propsData = {},
  } = {}) => {
    wrapper = shallowMount(GroupSelector, {
      apolloProvider: createMockApollo([[searchGroups, searchGroupsHandler]]),
      propsData,
      provide: {
        groupFullPath: undefined,
        ...provide,
      },
    });
  };

  const triggerDropdown = async () => {
    await findButton().trigger('click');
    await nextTick();
    findListbox().vm.$emit('shown');
    await nextTick();
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the add group button', () => {
      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toBe('Add group');
    });

    it('renders the button with secondary category', () => {
      expect(findButton().props('category')).toBe('secondary');
    });

    it('renders a "Create group" link with the default path', () => {
      expect(findCreateGroupLink().text()).toBe('Create group');
      expect(findCreateGroupLink().attributes('href')).toBe('/groups/new');
    });

    it('renders a "Create group" link that opens in a new tab', () => {
      expect(findCreateGroupLink().attributes('target')).toBe('_blank');
    });

    it('does not disable the button by default', () => {
      expect(findButton().props('disabled')).toBe(false);
    });

    it('renders the modal initially hidden', () => {
      expect(findModal().props('visible')).toBe(false);
    });

    it('renders the modal with correct title', () => {
      expect(findModal().props('title')).toBe('Add group');
    });

    it('renders the modal with correct size', () => {
      expect(findModal().props('size')).toBe('sm');
    });

    it('renders the collapsible listbox', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('renders the listbox with correct initial toggle text', () => {
      expect(findListbox().props('toggleText')).toBe('Select group');
    });
  });

  describe('group search', () => {
    it('fetches groups when dropdown is shown', async () => {
      createComponent();
      await triggerDropdown();

      expect(searchGroupsSuccessHandler).toHaveBeenCalledWith({
        search: '',
        parentPath: null,
        topLevelOnly: true,
      });
    });

    it('displays no results text when no groups are found', async () => {
      const emptyHandler = jest.fn().mockResolvedValue({
        data: {
          groups: {
            nodes: [],
          },
        },
      });

      createComponent({ searchGroupsHandler: emptyHandler });
      await triggerDropdown();

      expect(findListbox().props('noResultsText')).toBe('No groups found');
    });
  });

  describe('newGroupPath injection', () => {
    it('uses the injected newGroupPath for the Create group link', () => {
      createComponent({ provide: { newGroupPath: '/groups/new?parent_id=7#create-group-pane' } });

      expect(findCreateGroupLink().attributes('href')).toBe(
        '/groups/new?parent_id=7#create-group-pane',
      );
    });
  });

  describe('groupFullPath injection', () => {
    describe('when groupFullPath is provided', () => {
      const groupFullPath = 'parent-group';
      const parentPath = groupFullPath;

      beforeEach(() => {
        createComponent({
          provide: { groupFullPath },
        });
      });

      it('includes parentPath in query variables', async () => {
        await triggerDropdown();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith({
          search: '',
          parentPath,
          topLevelOnly: null,
        });
      });

      it('includes parentPath with search term in query variables', async () => {
        await triggerDropdown();

        findListbox().vm.$emit('search', 'test');
        await waitForPromises();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith({
          search: 'test',
          parentPath,
          topLevelOnly: null,
        });
      });

      it('does set topLevelOnly to null', async () => {
        await triggerDropdown();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith(
          expect.objectContaining({ topLevelOnly: null }),
        );
      });
    });

    describe('when groupFullPath is not provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('includes topLevelOnly in query variables', async () => {
        await triggerDropdown();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith({
          search: '',
          parentPath: null,
          topLevelOnly: true,
        });
      });

      it('includes topLevelOnly with search term in query variables', async () => {
        await triggerDropdown();

        findListbox().vm.$emit('search', 'test');
        await waitForPromises();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith({
          search: 'test',
          parentPath: null,
          topLevelOnly: true,
        });
      });

      it('does set parentPath to null', async () => {
        await triggerDropdown();

        expect(searchGroupsSuccessHandler).toHaveBeenCalledWith(
          expect.objectContaining({ parentPath: null }),
        );
      });
    });
  });

  describe('listbox items', () => {
    beforeEach(async () => {
      createComponent();
      await triggerDropdown();
      await waitForPromises();
      await nextTick();
    });

    it('renders listbox items with correct structure', () => {
      const items = findListbox().props('items');

      expect(items).toEqual([
        {
          value: mockGroup1.id,
          text: mockGroup1.name,
          fullPath: mockGroup1.fullPath,
        },
        {
          value: mockGroup2.id,
          text: mockGroup2.name,
          fullPath: mockGroup2.fullPath,
        },
        {
          value: mockGroup3.id,
          text: mockGroup3.name,
          fullPath: mockGroup3.fullPath,
        },
      ]);
    });
  });

  describe('add group action', () => {
    beforeEach(async () => {
      createComponent();
      await triggerDropdown();
      await waitForPromises();
      await nextTick();
    });

    it('emits groupSelected event with selected group when add button is clicked', async () => {
      findListbox().vm.$emit('select', mockGroup1.id);
      await nextTick();

      findModal().vm.$emit('primary');
      await nextTick();

      expect(wrapper.emitted('group-selected')).toEqual([[mockGroup1]]);
    });

    it('disables add button when no group is selected', () => {
      expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
    });
  });

  describe('when disabled prop is true', () => {
    beforeEach(() => {
      createComponent({ propsData: { disabled: true } });
    });

    it('disables the add group button', () => {
      expect(findButton().props('disabled')).toBe(true);
    });
  });

  describe('error handling', () => {
    it('displays error message when groups query fails', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Failed to fetch groups'));

      createComponent({ searchGroupsHandler: errorHandler });

      await triggerDropdown();
      await waitForPromises();

      expect(findListbox().props('noResultsText')).toBe('Failed to load groups');
    });
  });

  describe('modal action buttons', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders modal with correct action primary text', () => {
      expect(findModal().props('actionPrimary').text).toBe('Add');
    });

    it('renders modal with correct action primary variant', () => {
      expect(findModal().props('actionPrimary').attributes.variant).toBe('confirm');
    });

    it('renders modal with correct action cancel text', () => {
      expect(findModal().props('actionCancel').text).toBe('Cancel');
    });
  });
});
