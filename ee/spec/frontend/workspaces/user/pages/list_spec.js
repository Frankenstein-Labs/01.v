import { mount, shallowMount } from '@vue/test-utils';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlAlert, GlButton, GlLink, GlTabs } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkspaceEmptyState from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';
import WorkspaceTab from 'ee/workspaces/common/components/workspace_tab.vue';
import BaseWorkspacesList from 'ee/workspaces/common/components/workspaces_list/base_workspaces_list.vue';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import userWorkspacesTabListQuery from 'ee/workspaces/common/graphql/queries/user_workspaces_tab_list.query.graphql';
import getProjectsDetailsQuery from 'ee/workspaces/common/graphql/queries/get_projects_details.query.graphql';
import getWorkspaceStateQuery from 'ee/workspaces/common/graphql/queries/get_workspace_state.query.graphql';
import List from 'ee/workspaces/user/pages/list.vue';
import { ROUTES } from 'ee/workspaces/user/constants';
import { WORKSPACE_STATES } from 'ee/workspaces/common/constants';
import MonitorTerminatingWorkspace from 'ee/workspaces/common/components/monitor_terminating_workspace.vue';
import createRouter from 'ee/workspaces/user/router/index';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  USER_WORKSPACES_TAB_LIST_QUERY_RESULT,
  USER_WORKSPACES_TAB_LIST_QUERY_EMPTY_RESULT,
  GET_PROJECTS_DETAILS_QUERY_RESULT,
  GET_WORKSPACE_STATE_QUERY_RESULT,
} from '../../mock_data';

jest.mock('~/lib/logger');

Vue.use(VueApollo);
Vue.use(VueRouter);

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';

describe('workspaces/user/pages/list.vue', () => {
  let wrapper;
  let mockApollo;
  let userWorkspacesTabListQueryHandler;
  let getProjectsDetailsQueryHandler;
  let getWorkspaceStateQueryHandler;
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const buildMockApollo = () => {
    userWorkspacesTabListQueryHandler = jest
      .fn()
      .mockResolvedValue(USER_WORKSPACES_TAB_LIST_QUERY_RESULT);
    getProjectsDetailsQueryHandler = jest.fn().mockResolvedValue(GET_PROJECTS_DETAILS_QUERY_RESULT);
    getWorkspaceStateQueryHandler = jest.fn().mockResolvedValue(GET_WORKSPACE_STATE_QUERY_RESULT);

    mockApollo = createMockApollo([
      [userWorkspacesTabListQuery, userWorkspacesTabListQueryHandler],
      [getProjectsDetailsQuery, getProjectsDetailsQueryHandler],
      [getWorkspaceStateQuery, getWorkspaceStateQueryHandler],
    ]);
  };

  const createWrapper = ({ mountFn = shallowMount, stubs = {} } = {}) => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mountFn(List, {
      router: createRouter({ base: '/' }),
      apolloProvider: mockApollo,
      provide: {
        emptyStateSvgPath: SVG_PATH,
      },
      stubs,
    });
  };
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findTabContainer = () => wrapper.findComponent(GlTabs);
  const findTabs = () => wrapper.findAllComponents(WorkspaceTab);
  const findNewWorkspaceButton = () => wrapper.findComponent(GlButton);
  const findBaseWorkspacesList = () => wrapper.findComponent(BaseWorkspacesList);

  const findAllConfirmButtons = () =>
    wrapper.findAllComponents(GlButton).filter((button) => button.props().variant === 'confirm');

  beforeEach(() => {
    buildMockApollo();
  });

  describe('when no workspaces are available', () => {
    beforeEach(async () => {
      userWorkspacesTabListQueryHandler.mockReset();
      userWorkspacesTabListQueryHandler.mockResolvedValueOnce(
        USER_WORKSPACES_TAB_LIST_QUERY_EMPTY_RESULT,
      );

      createWrapper({
        stubs: {
          WorkspaceTab,
        },
      });
      await waitForPromises();
    });

    it('renders empty state when no workspaces are available', () => {
      expect(wrapper.findComponent(WorkspaceEmptyState).exists()).toBe(true);
    });

    it('renders only one confirm button when empty state is present', () => {
      expect(findAllConfirmButtons()).toHaveLength(1);
    });

    it('does not render the workspace tabs', () => {
      expect(findTabs().at(0).findComponent(WorkspaceEmptyState).exists()).toBe(true);
    });
  });

  it('shows loading state when workspaces are being fetched', () => {
    createWrapper();
    expect(findBaseWorkspacesList().props('loading')).toBe(true);
  });

  describe('default (with nodes)', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the workspace tabs', () => {
      const tabContainer = findTabContainer();
      const tabs = findTabs();

      expect(tabContainer.exists()).toBe(true);
      expect(tabContainer.props('syncActiveTabWithQueryParams')).toBe(true);

      expect(tabs.exists()).toBe(true);
      expect(tabs).toHaveLength(2);
      expect(tabs.at(0).props('tabName')).toBe('active');
      expect(tabs.at(1).props('tabName')).toBe('terminated');
    });

    it('does not call log error', () => {
      expect(logError).not.toHaveBeenCalled();
    });

    it('does not show alert', () => {
      expect(findAlert(wrapper).exists()).toBe(false);
    });

    it('calls trackEvent method when clicked on "New Workspace" button', () => {
      const { triggerEvent, trackEventSpy } = bindInternalEventDocument(wrapper.element);
      triggerEvent('[data-testid="list-new-workspace-button"]');

      expect(trackEventSpy).toHaveBeenCalledWith('click_new_workspace_button', {});
    });
  });

  describe('when workspace table emits update-failed event', () => {
    const error = 'Failed to stop workspace';

    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('displays the error attached to the event', async () => {
      findTabs().at(0).vm.$emit('error', error);
      await nextTick();

      expect(findBaseWorkspacesList().props('error')).toBe(error);
    });

    describe('when workspace table emits update-succeed event', () => {
      it('dismisses the previous update error', async () => {
        findTabs().at(0).vm.$emit('error', error);
        await nextTick();

        expect(findBaseWorkspacesList().props('error')).toBe(error);

        findTabs().at(0).vm.$emit('error', '');

        await nextTick();

        expect(findBaseWorkspacesList().props('error')).toBe('');
      });
    });
  });

  describe('when workspace tab emits on-pagination-input event', () => {
    const EXPECTED_ACTIVE_WORKSPACES_PAGINATION_VARIABLES = {
      first: 10,
      activeAfter: 'end',
      activeBefore: null,
      terminatedAfter: null,
      terminatedBefore: null,
    };
    const EXPECTED_TERMINATED_WORKSPACES_PAGINATION_VARIABLES = {
      first: 10,
      terminatedAfter: 'end',
      activeAfter: null,
      activeBefore: null,
      terminatedBefore: null,
    };

    it.each`
      tabName         | tabIdx | expectedPaginationVariables
      ${'active'}     | ${0}   | ${EXPECTED_ACTIVE_WORKSPACES_PAGINATION_VARIABLES}
      ${'terminated'} | ${1}   | ${EXPECTED_TERMINATED_WORKSPACES_PAGINATION_VARIABLES}
    `(
      'correctly sets pagination variables for $tabName tab',
      async ({ tabName, tabIdx, expectedPaginationVariables }) => {
        const pageVariables = { after: 'end', first: 10 };

        createWrapper();

        await waitForPromises();

        expect(userWorkspacesTabListQueryHandler).toHaveBeenCalledTimes(1);

        const workspaceTab = findTabs().at(tabIdx);

        workspaceTab.vm.$emit('on-pagination-input', {
          tab: tabName,
          paginationVariables: pageVariables,
        });

        await nextTick();

        expect(userWorkspacesTabListQueryHandler).toHaveBeenCalledTimes(2);
        expect(userWorkspacesTabListQueryHandler).toHaveBeenLastCalledWith(
          expectedPaginationVariables,
        );
      },
    );
  });

  describe.each`
    query                      | queryHandlerFactory
    ${'userWorkspacesTabList'} | ${() => userWorkspacesTabListQueryHandler}
    ${'projectsDetails'}       | ${() => getProjectsDetailsQueryHandler}
  `('when $query query fails', ({ queryHandlerFactory }) => {
    const ERROR = new Error('Something bad!');

    beforeEach(async () => {
      const queryHandler = queryHandlerFactory();

      queryHandler.mockReset();
      queryHandler.mockRejectedValueOnce(ERROR);

      createWrapper({ mountFn: mount });
      await waitForPromises();
    });

    it('logs error', () => {
      expect(logError).toHaveBeenCalledWith(ERROR);
    });

    it('shows alert', () => {
      expect(findAlert().text()).toBe(
        'Unable to load current workspaces. Please try again or contact an administrator.',
      );
    });

    it('hides error when alert is dismissed', async () => {
      findAlert().vm.$emit('dismiss');

      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('fixed elements', () => {
    beforeEach(async () => {
      createWrapper({
        stubs: {
          BaseWorkspacesList,
          IndexLayout,
          PageHeading,
        },
      });

      await waitForPromises();
    });

    it('displays a link button that navigates to the create workspace page', () => {
      expect(findNewWorkspaceButton().attributes().to).toBe(ROUTES.new);
      expect(findNewWorkspaceButton().text()).toMatch(/New workspace/);
    });

    it('displays a link that navigates to the workspaces help page', () => {
      expect(findHelpLink().attributes().href).toContain('user/workspace/_index.md');
    });
  });

  describe('terminating workspaces', () => {
    const MOCK_PAGE_INFO = {
      hasNextPage: false,
      hasPreviousPage: true,
      startCursor: 'start',
      endCursor: 'end',
    };

    const mockActiveWorkspaces =
      USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser.activeWorkspaces.nodes;

    const createMockTerminatingWorkspace = (id) => ({
      ...mockActiveWorkspaces[0],
      id,
      name: id,
      namespace: id,
      desiredState: WORKSPACE_STATES.terminated,
    });

    const createMockWorkspaceQueryResult = (workspaces) => ({
      data: {
        currentUser: {
          ...USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser,
          activeWorkspaces: {
            ...USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser.activeWorkspaces,
            nodes: [...workspaces],
            pageInfo: {
              ...USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser.activeWorkspaces.pageInfo,
              ...MOCK_PAGE_INFO,
            },
          },
        },
      },
    });

    beforeEach(async () => {
      const mockTerminatingWorkspacesQueryResult = createMockWorkspaceQueryResult([
        createMockTerminatingWorkspace('test1'),
        createMockTerminatingWorkspace('test2'),
        ...mockActiveWorkspaces,
      ]);
      userWorkspacesTabListQueryHandler.mockReset();
      userWorkspacesTabListQueryHandler.mockResolvedValueOnce(mockTerminatingWorkspacesQueryResult);
      createWrapper();
      await waitForPromises();
    });

    it('renders correct amount of MonitorTerminatingWorkspace components', () => {
      const monitorTerminatingWorkspaceComponents = wrapper.findAllComponents(
        MonitorTerminatingWorkspace,
      );
      expect(monitorTerminatingWorkspaceComponents).toHaveLength(2);
    });
  });
});
