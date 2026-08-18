import { GlSkeletonLoader, GlAlert, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkspacesList from 'ee/workspaces/common/components/workspaces_list/workspaces_list.vue';
import WorkspacesTable from 'ee/workspaces/common/components/workspaces_list/workspaces_table.vue';
import WorkspacesListPagination from 'ee/workspaces/common/components/workspaces_list/workspaces_list_pagination.vue';
import WorkspaceEmptyState from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';

const AGENT_NAME = 'agent-name';
const PROJECT_PATH = 'project/path';

describe('workspaces/common/components/workspaces_list/workspaces_list_spec.js', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(WorkspacesList, {
      propsData: {
        workspaces: [],
        pageInfo: {},
        pageSize: 10,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(WorkspacesTable);
  const findPagination = () => wrapper.findComponent(WorkspacesListPagination);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findHelpLink = () => wrapper.findComponent(GlLink);

  describe('When isLoading is true', () => {
    beforeEach(() => {
      createWrapper({ isLoading: true });
    });

    it('shows loading state when workspaces are being fetched', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('When no workspaces are available', () => {
    beforeEach(() => {
      createWrapper({ workspaces: [] });
    });

    it('renders empty state when no workspaces are available', () => {
      expect(wrapper.findComponent(WorkspaceEmptyState).exists()).toBe(true);
    });

    it('does not render the workspaces table', () => {
      expect(findTable().exists()).toBe(false);
    });

    it('does not render the workspaces pagination', () => {
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('When workspaces are set', () => {
    const workspaces = [1, 2, 3];

    beforeEach(() => {
      createWrapper({ workspaces });
    });

    it('renders table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('renders pagination', () => {
      expect(findPagination().exists()).toBe(true);
    });

    it('provides workspaces data to the workspaces table', () => {
      expect(findTable().props('workspaces')).toEqual(workspaces);
    });

    it('displays a link that navigates to the workspaces help page', () => {
      expect(findHelpLink().attributes().href).toContain('user/workspace/_index.md');
    });

    describe('When the pagination component emits input event', () => {
      it('emits a page event with the variables', () => {
        const pageVariables = {
          after: 'end',
          first: 10,
          agentName: AGENT_NAME,
          projectPath: PROJECT_PATH,
        };

        findPagination().vm.$emit('input', pageVariables);

        expect(wrapper.emitted('page')).toEqual([[pageVariables]]);
      });
    });

    describe('When the table component emits update-failed', () => {
      it('emits error with the error', () => {
        const error = 'My error';
        findTable().vm.$emit('update-failed', { error });

        expect(wrapper.emitted('error')).toEqual([[error]]);
      });
    });

    describe('When the table component emits update-succeed', () => {
      it('emits error with an empty string', () => {
        findTable().vm.$emit('update-succeed');

        expect(wrapper.emitted('error')).toEqual([['']]);
      });
    });
  });

  describe('When an error is set', () => {
    beforeEach(() => {
      createWrapper({ error: 'Error' });
    });

    it('displays an alert', () => {
      expect(findAlert().exists()).toBe(true);
    });
  });
});
