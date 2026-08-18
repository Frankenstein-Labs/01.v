import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlSkeletonLoader, GlTab } from '@gitlab/ui';
import WorkspaceTab from 'ee/workspaces/common/components/workspace_tab.vue';
import WorkspaceTable from 'ee/workspaces/common/components/workspaces_list/workspaces_table.vue';
import WorkspaceEmptyState from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';
import WorkspacesListPagination from 'ee/workspaces/common/components/workspaces_list/workspaces_list_pagination.vue';
import { populateWorkspacesWithProjectDetails } from 'ee/workspaces/common/services/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  USER_WORKSPACES_LIST_QUERY_RESULT,
  GET_PROJECTS_DETAILS_QUERY_RESULT,
} from '../../mock_data';

jest.mock('~/lib/logger');

Vue.use(VueApollo);

const MOCK_WORKSPACES = populateWorkspacesWithProjectDetails(
  USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
  GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
);

describe('workspaces/common/components/workspace_tab.vue', () => {
  let wrapper;
  const emptyStateSvgPath = '/placeholder.svg';

  const createWrapper = (props) => {
    wrapper = shallowMountExtended(WorkspaceTab, {
      provide: {
        emptyStateSvgPath,
      },
      propsData: {
        tabName: 'terminated',
        workspaces: MOCK_WORKSPACES,
        loading: false,
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
        },
        ...props,
      },
    });
  };
  const findTab = () => wrapper.findComponent(GlTab);
  const findTable = () => wrapper.findComponent(WorkspaceTable);
  const findPagination = () => wrapper.findComponent(WorkspacesListPagination);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(WorkspaceEmptyState);

  it('shows loading state when workspaces are being fetched', () => {
    createWrapper({ loading: true });
    expect(findLoader().exists()).toBe(true);
  });

  describe('when no workspaces are available', () => {
    beforeEach(() => {
      createWrapper({ workspaces: [] });
    });

    it('renders tab', () => {
      expect(findTab().exists()).toBe(true);
    });

    it('renders empty state when no workspaces are available', () => {
      const emptyState = findEmptyState();

      expect(emptyState.props()).toEqual({
        description: '',
        newWorkspacePath: '',
        title: 'No terminated workspaces',
      });
    });

    it('does not render table and pagination', () => {
      expect(findTable().exists()).toBe(false);
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('with workspaces', () => {
    beforeEach(() => {
      createWrapper({ workspaces: MOCK_WORKSPACES });
    });

    it('renders the tab', () => {
      expect(findTab().exists()).toBe(true);
    });

    it('renders table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('provides workspaces data to the workspaces table', () => {
      expect(findTable(wrapper).props('workspaces')).toEqual(MOCK_WORKSPACES);
    });

    it('renders pagination component', () => {
      expect(findPagination().exists()).toBe(true);
    });
  });

  describe('when pagination component emits events', () => {
    it.each(['active', 'terminated'])(
      'emits on-pagination-input event with correct variables for %s tab when input event is emitted',
      async (tab) => {
        const pageVariables = {
          after: 'end',
          first: 10,
        };

        createWrapper({ tabName: tab });

        await waitForPromises();

        findPagination().vm.$emit('input', pageVariables);

        await waitForPromises();

        expect(wrapper.emitted('on-pagination-input')).toHaveLength(1);
        expect(wrapper.emitted('on-pagination-input')[0]).toEqual([
          { tab, paginationVariables: pageVariables },
        ]);
      },
    );

    it('emits error event with error message when update-failed event is emitted', async () => {
      const mockError = 'Failed to stop workspace';
      createWrapper();

      await waitForPromises();
      findTable().vm.$emit('update-failed', { error: mockError });

      await nextTick();

      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(wrapper.emitted('error')[0]).toEqual([mockError]);
    });

    it('emits error event with empty string when update-succeed event is emitted', async () => {
      createWrapper();

      await waitForPromises();
      findTable().vm.$emit('update-succeed');

      await nextTick();

      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(wrapper.emitted('error')[0]).toEqual(['']);
    });
  });
});
