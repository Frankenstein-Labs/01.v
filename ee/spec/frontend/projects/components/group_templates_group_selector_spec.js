import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GroupTemplatesGroupSelector from 'ee/projects/components/group_templates_group_selector.vue';
import searchNamespacesWhereUserCanCreateProjectsQuery from '~/projects/new/queries/search_namespaces_where_user_can_create_projects.query.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

jest.mock('~/alert');

Vue.use(VueApollo);

const mockGroups = [
  {
    id: 'gid://gitlab/Group/1',
    fullPath: 'group-one',
    name: 'Group One',
    visibility: 'public',
    webUrl: '/group-one',
    canPushInitialCommit: true,
  },
  {
    id: 'gid://gitlab/Group/2',
    fullPath: 'group-two',
    name: 'Group Two',
    visibility: 'private',
    webUrl: '/group-two',
    canPushInitialCommit: true,
  },
];

const mockQueryResponse = {
  data: {
    currentUser: {
      id: 'gid://gitlab/User/1',
      groups: { nodes: mockGroups },
      namespace: {
        id: 'gid://gitlab/Namespace/1',
        fullPath: 'root',
        name: 'Root',
        visibility: 'public',
        webUrl: '/root',
        canPushInitialCommit: true,
      },
    },
  },
};

describe('GroupTemplatesGroupSelector', () => {
  let wrapper;
  let queryHandler;

  const createComponent = (handler = jest.fn().mockResolvedValue(mockQueryResponse)) => {
    queryHandler = handler;

    wrapper = shallowMountExtended(GroupTemplatesGroupSelector, {
      apolloProvider: createMockApollo([
        [searchNamespacesWhereUserCanCreateProjectsQuery, queryHandler],
      ]),
      provide: {
        newProjectPath: '/projects/new',
      },
    });
  };

  beforeEach(() => createComponent());

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const openDropdown = async () => {
    findListbox().vm.$emit('shown');
    await wrapper.vm.$apollo.queries.currentUser.refetch();
    jest.runOnlyPendingTimers();
    await waitForPromises();
  };

  it('renders the title and description', () => {
    expect(wrapper.findByTestId('group-templates-group-selector').exists()).toBe(true);
    expect(wrapper.text()).toContain('Select a group to view its project templates');
  });

  it('renders the listbox with the correct props', () => {
    expect(findListbox().props()).toMatchObject({
      toggleText: 'Select a group',
      positioningStrategy: 'fixed',
    });
  });

  it('does not fetch groups until the dropdown is opened', () => {
    expect(queryHandler).not.toHaveBeenCalled();
  });

  it('fetches groups when the dropdown is shown', async () => {
    await openDropdown();

    expect(queryHandler).toHaveBeenCalled();
  });

  it('renders group items after fetching', async () => {
    await openDropdown();

    expect(findListbox().props('items')).toEqual([
      { value: 'gid://gitlab/Group/1', text: 'group-one' },
      { value: 'gid://gitlab/Group/2', text: 'group-two' },
    ]);
  });

  it('navigates to the correct URL when a group is selected', async () => {
    await openDropdown();

    findListbox().vm.$emit('select', 'gid://gitlab/Group/1');

    expect(visitUrl).toHaveBeenCalledWith(
      expect.stringContaining('/projects/new?namespace_id=1&tab=group#create_from_template'),
    );
  });

  describe('when the GraphQL query fails', () => {
    beforeEach(async () => {
      createComponent(jest.fn().mockRejectedValue(new Error('GraphQL error')));

      findListbox().vm.$emit('shown');
      await nextTick();
      jest.runOnlyPendingTimers();
      await waitForPromises();
    });

    it('displays an error alert', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({ message: 'An error occurred while loading groups.' }),
      );
    });
  });
});
