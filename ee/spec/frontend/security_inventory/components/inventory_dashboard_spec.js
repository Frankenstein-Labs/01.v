import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlButton, GlIcon, GlKeysetPagination } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import { smoothScrollTop } from '~/lib/utils/scroll_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import {
  getLocationHash,
  queryToObject,
  setUrlParams,
  updateHistory,
} from '~/lib/utils/url_utility';
import InventoryDashboard from 'ee/security_inventory/components/inventory_dashboard.vue';
import RecursiveBreadcrumbs from 'ee/security_inventory/components/recursive_breadcrumbs.vue';
import VulnerabilityIndicator from 'ee/security_inventory/components/vulnerability_indicator.vue';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import SubgroupsAndProjectsQuery from 'ee/security_inventory/graphql/subgroups_and_projects.query.graphql';
import NamespaceSecurityProjectsQuery from 'ee/security_inventory/graphql/namespace_security_projects.query.graphql';
import SubgroupSidebar from 'ee/security_inventory/components/sidebar/subgroup_sidebar.vue';
import EmptyState from 'ee/security_inventory/components/empty_state.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import vulnerabilityCell from 'ee/security_inventory/components/vulnerability_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import SecurityInventoryTable from 'ee/security_inventory/components/security_inventory_table.vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import BulkEditActionsDropdown from 'ee/security_inventory/components/bulk_edit_actions_dropdown.vue';
import { MAX_SELECTED_COUNT } from 'ee/security_inventory/constants';
import {
  subgroupsAndProjects,
  namespaceSecurityProjectsResponse,
  mockAnalyzerFilter,
  mockVulnerabilityFilter,
  mockAttributeFilter,
} from '../mock_data';
import {
  createGroupResponse,
  createPaginatedHandler,
  createSearchResponse,
} from '../mock_pagination_helpers';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  getLocationHash: jest.fn().mockReturnValue(''),
  PATH_SEPARATOR: '/',
  queryToObject: jest.fn().mockReturnValue({}),
  setUrlParams: jest.fn().mockReturnValue(''),
  updateHistory: jest.fn(),
}));
jest.mock('~/helpers/help_page_helper', () => ({
  helpPagePath: jest.fn(),
}));
jest.mock('~/lib/utils/scroll_utils', () => ({
  smoothScrollTop: jest.fn(),
}));
jest.mock('ee/security_inventory/components/recursive_breadcrumbs.vue', () => ({
  name: 'RecursiveBreadcrumbs',
  props: ['currentPath', 'groupFullPath'],
  render() {},
}));

const setupDefaultUrlMocks = () => {
  getLocationHash.mockReturnValue('');
  queryToObject.mockReturnValue({});
  setUrlParams.mockReturnValue('');
  updateHistory.mockImplementation(() => {});
};

describe('InventoryDashboard', () => {
  let wrapper;
  let apolloProvider;
  let requestHandler = '';

  const childrenResolver = jest.fn().mockResolvedValue(subgroupsAndProjects);
  const searchResolver = jest.fn().mockResolvedValue(namespaceSecurityProjectsResponse);
  const mockChildren = [
    ...subgroupsAndProjects.data.group.descendantGroups.nodes,
    ...subgroupsAndProjects.data.group.projects.nodes,
  ];

  const defaultProvide = {
    groupFullPath: 'group/project',
    canManageAttributes: false,
    canReadAttributes: false,
    canApplyProfiles: false,
    groupId: '33',
    newProjectPath: '/new',
    glFeatures: {
      securityInventoryPagination: false,
      securityScanProfiles: true,
    },
  };

  const createComponentFactory =
    (mountFn = shallowMountExtended) =>
    async ({
      resolver = childrenResolver,
      searchQueryResolver = searchResolver,
      provide = {},
    } = {}) => {
      requestHandler = resolver;
      apolloProvider = createMockApollo([
        [SubgroupsAndProjectsQuery, resolver],
        [NamespaceSecurityProjectsQuery, searchQueryResolver],
      ]);
      wrapper = mountFn(InventoryDashboard, {
        apolloProvider,
        provide: { ...defaultProvide, ...provide },
        stubs: {
          SubgroupSidebar: stubComponent(SubgroupSidebar),
          InventoryDashboardFilteredSearchBar: stubComponent(InventoryDashboardFilteredSearchBar),
          RecursiveBreadcrumbs: stubComponent(RecursiveBreadcrumbs, {
            props: ['currentPath', 'groupFullPath'],
          }),
        },
        directives: {
          GlTooltip: createMockDirective('gl-tooltip'),
        },
      });
      await waitForPromises();
      if (wrapper.vm.$refs.inventoryTable) {
        wrapper.vm.$refs.inventoryTable.clearSelection = jest.fn();
      }
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mountExtended);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findEmptyState = () => wrapper.findComponent(EmptyState);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findBreadcrumb = () => wrapper.findComponent(RecursiveBreadcrumbs);
  const findSidebar = () => wrapper.findComponent(SubgroupSidebar);
  const findSidebarToggleButton = () => wrapper.findComponent(GlButton);
  const findInventoryTable = () => wrapper.findComponent(SecurityInventoryTable);
  const loadMoreButton = () => wrapper.findComponentByTestId('load-more-button');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findFilteredSearchBar = () => wrapper.findComponent(InventoryDashboardFilteredSearchBar);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBulkEditActionsDropdown = () => wrapper.findComponent(BulkEditActionsDropdown);
  const findEditAttributesButton = () => wrapper.findByTestId('edit-attributes-button');

  /* eslint-disable no-underscore-dangle */
  const getIndexByType = (children, type) => {
    return children.findIndex((child) => child.__typename === type);
  };
  /* eslint-enable no-underscore-dangle */

  beforeEach(async () => {
    setupDefaultUrlMocks();
    await createComponent();
  });

  it('displays default state correctly', () => {
    expect(wrapper.exists()).toBe(true);

    expect(findEmptyState().exists()).toBe(false);
    expect(findInventoryTable().exists()).toBe(true);
    expect(findInventoryTable().props('isLoading')).toBe(false);
    expect(findFilteredSearchBar().exists()).toBe(true);
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      const mockHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      await createComponent({ resolver: mockHandler });
    });

    it('sets loading state correctly', () => {
      expect(findInventoryTable().props('isLoading')).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('Empty state', () => {
    it('displays empty state when there are no children', async () => {
      const emptyResolver = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'gid://Gitlab/Group/17',
            descendantGroups: { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } },
            projects: { nodes: [], pageInfo: { hasNextPage: false, endCursor: null } },
          },
        },
      });
      await createComponent({ resolver: emptyResolver });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('Table rendering', () => {
    const groupIndex = getIndexByType(mockChildren, 'Group');
    const projectIndex = getIndexByType(mockChildren, 'Project');

    beforeEach(async () => {
      await createFullComponent();
    });

    it('renders the GlTableLite component with correct fields', () => {
      expect(findTable().exists()).toBe(true);
      expect(findTable().props('fields')).toHaveLength(4);
      expect(
        findTable()
          .props('fields')
          .map((field) => field.key),
      ).toEqual(['name', 'vulnerabilities', 'toolCoverage', 'actions']);
    });

    it('renders correct values in table cells for projects and subgroups', () => {
      expect(findTableRows()).toHaveLength(mockChildren.length);

      const nameCell = findNthTableRow(groupIndex).findComponent(NameCell);
      expect(nameCell.exists()).toBe(true);
      expect(nameCell.text()).toContain(mockChildren[0].name);

      const vulnerabilitycell = findNthTableRow(groupIndex).findComponent(vulnerabilityCell);
      expect(vulnerabilitycell.exists()).toBe(true);
      expect(vulnerabilitycell.text()).toContain('80');

      const toolCoverageCell = findNthTableRow(groupIndex).findComponent(ToolCoverageCell);
      expect(toolCoverageCell.exists()).toBe(true);

      const actionCell = findNthTableRow(projectIndex).findComponent(ActionCell);
      expect(actionCell.exists()).toBe(true);
    });

    it('renders correct elements for projects and subgroups', () => {
      const subgroupLink = findNthTableRow(groupIndex).findComponent({ name: 'gl-link' });
      expect(subgroupLink.exists()).toBe(true);
      expect(subgroupLink.attributes('href')).toBe(`#${mockChildren[groupIndex].fullPath}`);

      const projectDiv = findNthTableRow(projectIndex).find('div');
      expect(projectDiv.exists()).toBe(true);
      expect(projectDiv.text()).toContain(mockChildren[projectIndex].name);
    });

    it('renders the vulnerability indicator for projects and subgroups', () => {
      expect(
        findNthTableRow(projectIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 5,
        low: 4,
        info: 0,
        medium: 48,
        unknown: 7,
        updatedAt: '2025-01-01T00:00:00Z',
      });
      expect(
        findNthTableRow(groupIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 10,
        low: 10,
        info: 10,
        medium: 20,
        unknown: 20,
        updatedAt: '2025-01-01T00:00:00Z',
      });
    });

    it('renders tool coverage indicators for projects and subgroups', async () => {
      await createFullComponent();
      expect(
        findNthTableRow(projectIndex).findComponent(ProjectToolCoverageIndicator).props('item')
          .analyzerStatuses,
      ).toEqual([
        {
          analyzerType: 'SAST',
          buildId: 'gid://git/path/123',
          lastCall: '2025-01-01T00:00:00Z',
          status: 'SUCCESS',
          updatedAt: '2025-01-01T00:00:00Z',
        },
      ]);
      expect(findNthTableRow(groupIndex).findComponent(GroupToolCoverageIndicator).exists()).toBe(
        true,
      );
    });
  });

  describe('Subgroup sidebar', () => {
    it('can be toggled with the sidebar button', async () => {
      await createComponent();

      expect(findSidebar().exists()).toBe(true);

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });

    it('persists visible state through page reloads', async () => {
      createFullComponent();

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);

      wrapper.destroy();
      createFullComponent();
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });
  });

  describe('Error handling', () => {
    it('captures exception in Sentry when an unexpected error occurs', async () => {
      jest.spyOn(Sentry, 'captureException');
      const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

      await createComponent({ resolver: mockErrorResolver });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while fetching subgroups and projects. Please try again.',
        }),
      );

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
    });

    describe('withPaginationErrorHandling', () => {
      beforeEach(async () => {
        await createComponent({
          provide: {
            glFeatures: {
              securityInventoryPagination: true,
            },
          },
        });
        wrapper.vm.currentPage = mockChildren;
        await nextTick();
      });

      describe.each`
        scenario                                  | triggerAction                                                                                  | paginatorMethod
        ${'fetching next page'}                   | ${() => findPagination().vm.$emit('next')}                                                     | ${'getNextCombinedPage'}
        ${'fetching previous page'}               | ${() => findPagination().vm.$emit('prev')}                                                     | ${'getPreviousCombinedPage'}
        ${'resetting paginator on filter change'} | ${() => findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: 'test' })} | ${'reset'}
        ${'resetting paginator on hash change'}   | ${() => window.dispatchEvent(new Event('hashchange'))}                                         | ${'reset'}
        ${'refetching data'}                      | ${() => wrapper.vm.refetchData()}                                                              | ${'refetch'}
      `('handles errors when $scenario', ({ triggerAction, paginatorMethod }) => {
        it('shows alert, captures error in Sentry, and resets loading state', async () => {
          const error = new Error(`Failed during ${paginatorMethod}`);
          jest.spyOn(Sentry, 'captureException');
          jest.spyOn(wrapper.vm.paginator, paginatorMethod).mockRejectedValue(error);
          getLocationHash.mockReturnValue('new-group-path');

          triggerAction();
          await nextTick();
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message: 'An error occurred while fetching subgroups and projects. Please try again.',
              error,
              captureError: true,
            }),
          );
          expect(Sentry.captureException).toHaveBeenCalledWith(error);
          expect(smoothScrollTop).toHaveBeenCalled();
          expect(findInventoryTable().props('isLoading')).toBe(false);
        });
      });
    });
  });

  describe('opening subgroup details', () => {
    it('refetches data when URL hash changes', async () => {
      const newFullPath = 'new-group';
      getLocationHash.mockReturnValue(newFullPath);

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: newFullPath,
        }),
      );
    });

    it('fallback to groupFullPath when hash is removed', async () => {
      getLocationHash.mockReturnValue('');

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: defaultProvide.groupFullPath,
        }),
      );
    });
  });

  describe('RecursiveBreadcrumbs', () => {
    it('renders component with correct props', () => {
      expect(findBreadcrumb().props()).toStrictEqual({
        groupFullPath: 'group/project',
        currentPath: 'group/project',
      });
    });

    it('updates props when activeFullPath changes', async () => {
      getLocationHash.mockReturnValue('group/project/subgroup');
      await createComponent();

      expect(findBreadcrumb().props()).toStrictEqual({
        groupFullPath: 'group/project',
        currentPath: 'group/project/subgroup',
      });
    });
  });

  describe('Pagination', () => {
    describe('Previous next functionality (feature flag enabled)', () => {
      beforeEach(async () => {
        await createComponent({
          provide: {
            glFeatures: {
              securityInventoryPagination: true,
            },
          },
        });
        await nextTick();
      });

      it('initializes a sequential paginator', () => {
        expect(wrapper.vm.paginator).toBeDefined();
        expect(wrapper.vm.paginator.pageSize).toBe(20);
        expect(wrapper.vm.paginator.resources).toHaveLength(2);
      });

      it('renders a GlKeysetPagination that uses hasNextPage and hasPreviousPage from the paginator', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props('hasNextPage')).toBe(wrapper.vm.paginator.hasNextPage());
        expect(findPagination().props('hasPreviousPage')).toBe(
          wrapper.vm.paginator.hasPreviousPage(),
        );
        expect(loadMoreButton().exists()).toBe(false);
      });

      it('fetches next page, sets loading state, updates currentPage, and displays results when next button is clicked', async () => {
        const mockNextPageData = [{ id: 'new-item-1' }, { id: 'new-item-2' }];
        const getNextCombinedPageSpy = jest
          .spyOn(wrapper.vm.paginator, 'getNextCombinedPage')
          .mockResolvedValue(mockNextPageData);

        findPagination().vm.$emit('next');
        await nextTick();

        expect(getNextCombinedPageSpy).toHaveBeenCalledWith(wrapper.vm.variables);
        expect(findInventoryTable().props('isLoading')).toBe(true);

        await waitForPromises();

        expect(smoothScrollTop).toHaveBeenCalled();
        expect(findInventoryTable().props('isLoading')).toBe(false);
        expect(wrapper.vm.currentPage).toEqual(mockNextPageData);
        expect(findInventoryTable().props('items')).toStrictEqual(wrapper.vm.currentPage);
      });

      it('fetches previous page, sets loading state, updates currentPage, and displays results when previous button is clicked', async () => {
        const mockPrevPageData = [{ id: 'prev-item-1' }, { id: 'prev-item-2' }];
        const getPreviousCombinedPageSpy = jest
          .spyOn(wrapper.vm.paginator, 'getPreviousCombinedPage')
          .mockResolvedValue(mockPrevPageData);

        findPagination().vm.$emit('prev');
        await nextTick();

        expect(getPreviousCombinedPageSpy).toHaveBeenCalledWith(wrapper.vm.variables);
        expect(findInventoryTable().props('isLoading')).toBe(true);

        await waitForPromises();

        expect(smoothScrollTop).toHaveBeenCalled();
        expect(findInventoryTable().props('isLoading')).toBe(false);
        expect(wrapper.vm.currentPage).toEqual(mockPrevPageData);
        expect(findInventoryTable().props('items')).toStrictEqual(wrapper.vm.currentPage);
      });

      it('resets paginator when filters change', async () => {
        const resetSpy = jest.spyOn(wrapper.vm.paginator, 'reset').mockResolvedValue([]);

        findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: 'test' });
        await nextTick();
        await waitForPromises();

        expect(resetSpy).toHaveBeenCalledWith(wrapper.vm.variables);
      });

      it('resets paginator when activeFullPath changes', async () => {
        const resetSpy = jest.spyOn(wrapper.vm.paginator, 'reset').mockResolvedValue([]);
        getLocationHash.mockReturnValue('new-group-path');

        window.dispatchEvent(new Event('hashchange'));
        await waitForPromises();

        expect(resetSpy).toHaveBeenCalledWith(wrapper.vm.variables);
      });

      it('calls refetch on paginator when refetchData is called', async () => {
        const refetchSpy = jest.spyOn(wrapper.vm.paginator, 'refetch').mockResolvedValue([]);

        await wrapper.vm.refetchData();

        expect(refetchSpy).toHaveBeenCalledWith(wrapper.vm.variables);
      });
    });

    describe('Load more functionality (feature flag disabled)', () => {
      it('does not render the Load more button by default', () => {
        expect(loadMoreButton().exists()).toBe(false);
      });

      it('does not show Load more button for subgroups when search is active', async () => {
        const resolver = jest.fn().mockResolvedValue(
          createGroupResponse({
            subgroupsPageInfo: { hasNextPage: true, endCursor: 'abc123' },
          }),
        );

        await createComponent({ resolver });
        await waitForPromises();

        // Without search, the button should be visible
        expect(loadMoreButton().exists()).toBe(true);

        // Activate search mode - subgroup pagination should no longer show the button
        wrapper.vm.$data.filters = { search: 'test' };
        wrapper.vm.$data.projectsPageInfo = { hasNextPage: false, endCursor: null };
        await nextTick();

        expect(wrapper.vm.hasSearch).toBe(true);
        expect(loadMoreButton().exists()).toBe(false);
      });

      it('shows Load more button when more subgroups are available', async () => {
        const resolver = jest.fn().mockResolvedValue(
          createGroupResponse({
            subgroupsPageInfo: { hasNextPage: true, endCursor: 'abc123' },
          }),
        );

        await createComponent({ resolver });
        await waitForPromises();

        expect(loadMoreButton().exists()).toBe(true);
        expect(findPagination().exists()).toBe(false);
      });

      it('shows Load more button when more projects are available and subgroups are fully loaded', async () => {
        const resolver = jest.fn().mockResolvedValue(
          createGroupResponse({
            subgroups: [],
            subgroupsPageInfo: { hasNextPage: false, endCursor: null },
            projectsPageInfo: { hasNextPage: true, endCursor: 'def456' },
          }),
        );

        await createComponent({ resolver });
        await waitForPromises();

        expect(loadMoreButton().exists()).toBe(true);
        expect(findPagination().exists()).toBe(false);
      });

      it('fetches more projects when Load more button is clicked during project pagination', async () => {
        const handler = createPaginatedHandler({
          first: {
            subgroups: [],
            subgroupsPageInfo: { hasNextPage: false, endCursor: null },
            projectsPageInfo: { hasNextPage: true, endCursor: 'project-cursor-123' },
          },
          second: {
            projects: [],
            projectsPageInfo: { hasNextPage: false, endCursor: null },
          },
        });

        await createComponent({ resolver: handler });
        await waitForPromises();

        loadMoreButton().vm.$emit('click');
        await waitForPromises();

        expect(handler.mock.calls[1][0]).toEqual({
          fullPath: defaultProvide.groupFullPath,
          subgroupsFirst: 0,
          subgroupsAfter: null,
          projectsFirst: 20,
          projectsAfter: 'project-cursor-123',
          canReadAttributes: false,
        });
      });

      it('appends search results when Load more is clicked with filters active', async () => {
        const secondPageProject = {
          ...subgroupsAndProjects.data.group.projects.nodes[0],
          id: 'gid://gitlab/Project/200',
          name: 'Second page project',
        };

        const secondSearchResponse = createSearchResponse({
          namespaceSecurityProjects: [{ node: secondPageProject }],
          projectsPageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            endCursor: null,
            startCursor: null,
            __typename: 'PageInfo',
          },
        });

        const searchHandler = jest.fn().mockResolvedValue(secondSearchResponse);

        await createComponent({ searchQueryResolver: searchHandler });

        // Stop the smart queries from interfering
        wrapper.vm.$apollo.queries.searchResults.stop();
        wrapper.vm.$apollo.queries.subgroupItems.stop();

        // After the initial browse query, projectItems contains browse-mode projects.
        // Simulate entering search mode with a paginated result.
        wrapper.vm.$data.filters = { search: 'test' };
        wrapper.vm.$data.displayItems = [];
        wrapper.vm.$data.projectsPageInfo = { hasNextPage: true, endCursor: 'search-cursor-1' };
        await nextTick();

        expect(wrapper.vm.hasSearch).toBe(true);
        // projectItems still has the browse-mode projects from the initial load
        expect(wrapper.vm.projectItems).toHaveLength(2);

        // Click load more - this calls loadMoreSearchResults
        loadMoreButton().vm.$emit('click');
        await waitForPromises();

        // The displayItems should only contain the new search results,
        // NOT the browse-mode projectItems (which would be the bug).
        const items = wrapper.vm.displayItems;
        const itemNames = items.map((i) => i.name);
        expect(itemNames).not.toContain('security-reports-example');
        expect(itemNames).not.toContain('Flight');
        expect(itemNames).toContain('Second page project');
      });

      it('fetches more subgroups when Load more button is clicked during subgroup pagination', async () => {
        const handler = createPaginatedHandler({
          first: {
            subgroupsPageInfo: { hasNextPage: true, endCursor: 'subgroup-cursor-999' },
            projects: [],
          },
          second: {
            subgroups: [],
            subgroupsPageInfo: { hasNextPage: false, endCursor: null },
            projects: [],
          },
        });

        await createComponent({ resolver: handler });
        await waitForPromises();

        loadMoreButton().vm.$emit('click');
        await waitForPromises();

        expect(handler.mock.calls[1][0]).toEqual({
          fullPath: defaultProvide.groupFullPath,
          subgroupsFirst: 20,
          subgroupsAfter: 'subgroup-cursor-999',
          projectsFirst: 0,
          projectsAfter: null,
          canReadAttributes: false,
        });
      });
    });
  });

  describe('filtered search', () => {
    it('passes the filters to the filtered search bar', async () => {
      queryToObject.mockReturnValue({
        search: 'test-search',
      });
      await createComponent();

      expect(findFilteredSearchBar().props('initialFilters')).toEqual({
        search: 'test-search',
      });
    });

    it('passes the namespace to the filtered search bar', async () => {
      getLocationHash.mockReturnValue('group/project');
      await createComponent();

      expect(findFilteredSearchBar().props('namespace')).toBe('group/project');
    });

    it('updates query variables and clears the selection when filter changes', async () => {
      const filters = {
        search: 'test query',
        securityAnalyzerFilters: [mockAnalyzerFilter],
        vulnerabilityCountFilters: [mockVulnerabilityFilter],
        attributeFilters: [mockAttributeFilter],
      };
      const mockSearchResolver = jest.fn().mockResolvedValue(namespaceSecurityProjectsResponse);
      await createFullComponent({ searchQueryResolver: mockSearchResolver });
      const clearSelectionSpy = jest.fn();
      wrapper.vm.$refs.inventoryTable.clearSelection = clearSelectionSpy;

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', filters);
      await nextTick();
      await waitForPromises();
      expect(mockSearchResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test query',
          securityAnalyzerFilters: [mockAnalyzerFilter],
          vulnerabilityCountFilters: [mockVulnerabilityFilter],
          attributeFilters: [mockAttributeFilter],
        }),
      );
      expect(clearSelectionSpy).toHaveBeenCalled();
    });

    it('forwards status booleans to the search query when a status filter is set', async () => {
      const mockSearchResolver = jest.fn().mockResolvedValue(namespaceSecurityProjectsResponse);
      await createComponent({ searchQueryResolver: mockSearchResolver });

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { hasStale: true });
      await nextTick();
      await waitForPromises();

      expect(mockSearchResolver).toHaveBeenCalledWith(expect.objectContaining({ hasStale: true }));
    });

    it('preserves hash when updating URL with search parameters', async () => {
      getLocationHash.mockReturnValue('group/path');
      setUrlParams.mockReturnValue('http://localhost?search=test');

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: 'test' });
      await nextTick();
      expect(updateHistory).toHaveBeenCalledWith({
        url: expect.stringContaining('#group/path'),
      });
    });

    it('switches to browse query when search is cleared', async () => {
      const mockSearchResolver = jest.fn().mockResolvedValue(namespaceSecurityProjectsResponse);
      await createComponent({ searchQueryResolver: mockSearchResolver });

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: 'test' });
      await nextTick();
      await waitForPromises();
      expect(mockSearchResolver).toHaveBeenCalled();

      mockSearchResolver.mockClear();
      requestHandler.mockClear();

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: '' });
      await nextTick();
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalled();
    });

    it('uses search query when filters are active', async () => {
      const mockSearchResolver = jest.fn().mockResolvedValue(namespaceSecurityProjectsResponse);
      await createComponent({ searchQueryResolver: mockSearchResolver });

      findFilteredSearchBar().vm.$emit('filter-subgroups-and-projects', { search: 'test' });
      await nextTick();
      await waitForPromises();

      expect(mockSearchResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test',
        }),
      );
    });
  });

  describe('bulk selection summary', () => {
    it('shows the selected items count', async () => {
      wrapper.findComponent(SecurityInventoryTable).vm.$emit('selected-count', 10);

      await nextTick();

      expect(wrapper.html()).toContain('%{strongStart}10%{strongEnd} items selected');
      expect(findIcon().exists()).toBe(false);
    });

    it('shows a warning when the selection limit is reached', async () => {
      wrapper.findComponent(SecurityInventoryTable).vm.$emit('selected-count', MAX_SELECTED_COUNT);

      await nextTick();

      expect(wrapper.html()).toContain('%{strongStart}100%{strongEnd} items selected');
      expect(findIcon().props('name')).toBe('warning');
      expect(getBinding(findIcon().element, 'gl-tooltip').value).toBe(
        `You can edit up to ${MAX_SELECTED_COUNT} items at once`,
      );
    });
  });

  describe('bulk edit actions dropdown', () => {
    describe('when securityScanProfilesFeature is enabled and user has canApplyProfiles permission', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            canApplyProfiles: true,
            glFeatures: {
              securityScanProfilesFeature: true,
              securityInventoryPagination: false,
            },
          },
        });
        if (wrapper.vm.$refs.inventoryTable) {
          wrapper.vm.$refs.inventoryTable.bulkEdit = jest.fn();
        }
        wrapper.findComponent(SecurityInventoryTable).vm.$emit('selected-count', 10);
        await nextTick();
      });

      it('renders BulkEditActionsDropdown instead of "Edit security attributes" button', () => {
        expect(findBulkEditActionsDropdown().exists()).toBe(true);
      });

      it('passes bulk-edit event to inventory table with correct action type', async () => {
        findBulkEditActionsDropdown().vm.$emit('bulk-edit', 'SCANNERS');
        await nextTick();

        expect(wrapper.vm.$refs.inventoryTable.bulkEdit).toHaveBeenCalledWith('SCANNERS');
      });

      it('does not render button', () => {
        expect(findEditAttributesButton().exists()).toBe(false);
      });
    });

    describe('when securityScanProfilesFeature is disabled', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            canManageAttributes: true,
          },
        });
        wrapper.findComponent(SecurityInventoryTable).vm.$emit('selected-count', 10);
        await nextTick();
      });

      it('renders single "Edit security attributes" button when user has canManageAttributes', () => {
        expect(findEditAttributesButton().exists()).toBe(true);
      });

      it('does not render BulkEditActionsDropdown', () => {
        expect(findBulkEditActionsDropdown().exists()).toBe(false);
      });
    });
  });
});
