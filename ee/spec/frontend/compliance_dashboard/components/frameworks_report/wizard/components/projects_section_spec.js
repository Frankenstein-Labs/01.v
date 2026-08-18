import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable } from '@gitlab/ui';

import Pagination from 'ee/compliance_dashboard/components/shared/pagination.vue';
import Filters from 'ee/compliance_dashboard/components/shared/filters.vue';

import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/projects_section.vue';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';
import createMockApollo from 'helpers/mock_apollo_helper';

import { mountExtended } from 'helpers/vue_test_utils_helper';

import complianceFrameworksGroupProjects from 'ee/compliance_dashboard/graphql/compliance_frameworks_group_projects.query.graphql';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import searchGroupsQuery from '~/boards/graphql/sub_groups.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { i18n } from 'ee/compliance_dashboard/components/frameworks_report/wizard/constants';
import { createFramework, createProject } from '../../../../mock_data';

Vue.use(VueApollo);

describe('Projects section', () => {
  let wrapper;
  let apolloProvider;
  let queryMock;

  const framework = createFramework({ id: 1, projects: 3 });
  const projects = framework.projects.nodes;

  const createMockApolloProvider = (resolverMock) => {
    // Mock response for compliance frameworks token
    const frameworksResponse = {
      data: {
        namespace: {
          id: 'gid://gitlab/Group/1',
          name: 'Gitlab Org',
          complianceFrameworks: {
            nodes: [
              {
                id: 'gid://gitlab/ComplianceManagement::Framework/1',
                name: 'Framework 1',
                default: false,
                description: 'Description 1',
                color: '#ff0000',
                pipelineConfigurationFullPath: null,
                projects: {
                  nodes: [],
                },
              },
            ],
            pageInfo: {
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: null,
              endCursor: null,
              __typename: 'PageInfo',
            },
          },
        },
      },
    };

    // Mock response for sub groups query
    const subGroupsResponse = {
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Gitlab Org',
          fullName: 'Gitlab Organization',
          fullPath: 'gitlab-org',
          __typename: 'Group',
          descendantGroups: {
            nodes: [
              {
                id: 'gid://gitlab/Group/2',
                name: 'Subgroup 1',
                fullName: 'Gitlab Organization / Subgroup 1',
                fullPath: 'gitlab-org/subgroup-1',
                __typename: 'Group',
              },
              {
                id: 'gid://gitlab/Group/3',
                name: 'Subgroup 2',
                fullName: 'Gitlab Organization / Subgroup 2',
                fullPath: 'gitlab-org/subgroup-2',
                __typename: 'Group',
              },
            ],
            pageInfo: {
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: null,
              endCursor: null,
              __typename: 'PageInfo',
            },
            __typename: 'GroupConnection',
          },
        },
      },
    };

    queryMock = resolverMock;
    const requestHandlers = [
      [complianceFrameworksGroupProjects, resolverMock],
      [getComplianceFrameworkQuery, jest.fn().mockResolvedValue(frameworksResponse)],
      [searchGroupsQuery, jest.fn().mockResolvedValue(subGroupsResponse)],
    ];
    return createMockApollo(requestHandlers);
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const projectLinks = () => wrapper.findAllByTestId('project-link');
  const subgroupLinks = () => wrapper.findAllByTestId('subgroup-link');
  const findCheckbox = (idx) => findTableRow(idx).find('input[type="checkbox"]');
  const findSelectAllCheckbox = () => wrapper.findByTestId('select-all-checkbox');
  const findPagination = () => wrapper.findComponent(Pagination);
  const findShowOnlySelectedToggle = () =>
    wrapper.findComponentByTestId('show-only-selected-toggle');

  const mockProjects = Array.from({ length: 5 }, (_, id) =>
    createProject({ id, groupPath: 'foo' }),
  );

  let dataMock;
  const createComponent = ({
    resolverMock = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          projects: {
            nodes: mockProjects,
            pageInfo: {
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: null,
              endCursor: null,
              __typename: 'PageInfo',
            },
            __typename: 'ProjectConnection',
          },
        },
      },
    }),
  } = {}) => {
    apolloProvider = createMockApolloProvider(resolverMock);
    dataMock = resolverMock;

    wrapper = mountExtended(ProjectsSection, {
      apolloProvider,
      propsData: {
        complianceFramework: framework,
        groupPath: 'gitlab-org',
      },
    });
  };

  it('triggers load on mount (section is always expanded)', async () => {
    createComponent();
    await waitForPromises();
    await nextTick();
    expect(dataMock).toHaveBeenCalled();
  });

  describe('when loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Projects');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        "All selected projects will be covered by the framework's selected requirements and the policies.",
      );
      expect(description).toBeDefined();
    });

    it('displays the correct total count of associated projects from projects.count in the count badge', () => {
      const frameworkWithManyProjects = createFramework({
        id: 1,
        projects: 3,
        projectsTotalCount: 155,
      });

      const wrapperWithManyProjects = mountExtended(ProjectsSection, {
        apolloProvider,
        propsData: {
          complianceFramework: frameworkWithManyProjects,
          groupPath: 'gitlab-org',
        },
      });

      const countBadge = wrapperWithManyProjects.findByTestId('count-badge');
      expect(countBadge.text()).toBe('155');
    });

    it('correctly calculates projects', () => {
      const items = findTable().props('items');
      expect(items).toHaveLength(5);
    });

    it.each(Object.keys(projects))('has the correct data for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d.text());

      expect(frameworkProjects[1]).toMatch(projects[idx].name);
      expect(frameworkProjects[2]).toMatch(projects[idx].namespace.fullName);
      expect(frameworkProjects[3]).toMatch(projects[idx].description);
    });

    it.each(Object.keys(projects))('has the correct visibility icon for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d);

      const visibilityIcon = frameworkProjects[1].findComponent(VisibilityIconButton);
      expect(visibilityIcon.exists()).toBe(true);
      expect(visibilityIcon.props('visibilityLevel')).toMatch(projects[idx].visibility);
    });

    it.each(Object.keys(projects))('renders correct url for the projects %s', (idx) => {
      expect(projectLinks().at(idx).attributes('href')).toBe(projects[idx].webPath);
    });

    it.each(Object.keys(projects))('renders correct url for the projects subgroup %s', (idx) => {
      expect(subgroupLinks().at(idx).attributes('href')).toBe(projects[idx].namespace.webUrl);
    });

    describe('project selection', () => {
      it('selects all projects when select all checkbox is clicked', async () => {
        await findSelectAllCheckbox().setChecked(true);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        const lastEvent = emittedEvents[emittedEvents.length - 1][0];

        expect(lastEvent.addProjects).toHaveLength(wrapper.findAll('tbody > tr').length);
        expect(lastEvent.removeProjects).toHaveLength(0);
      });

      it('deselects all projects when select all checkbox is unchecked', async () => {
        await findSelectAllCheckbox().setChecked(true);
        await nextTick();
        await findSelectAllCheckbox().setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        const lastEvent = emittedEvents[emittedEvents.length - 1][0];
        expect(lastEvent.addProjects).toHaveLength(0);
        expect(lastEvent.removeProjects).toHaveLength(wrapper.findAll('tbody > tr').length);
      });

      it('selects individual project when checkbox is clicked', async () => {
        const checkbox = findCheckbox(4);
        await checkbox.setChecked(true);
        await nextTick();

        expect(checkbox.element.checked).toBe(true);

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents[0][0].addProjects).toContain(getIdFromGraphQLId(mockProjects[4].id));
      });

      it('emits update:projects event with correct data when projects are selected', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(1);
        const [eventData] = emittedEvents[0];
        expect(eventData).toEqual({
          addProjects: [getIdFromGraphQLId(mockProjects[4].id)],
          removeProjects: [],
        });
      });

      it('emits update:projects event when multiple projects are selected', async () => {
        await findCheckbox(3).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(3);
        const [lastEventData] = emittedEvents[2];
        expect(lastEventData).toEqual({
          addProjects: [getIdFromGraphQLId(mockProjects[3].id)],
          removeProjects: [getIdFromGraphQLId(mockProjects[4].id)],
        });
      });

      it('emits update:projects event when projects are deselected', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(2);
        const [lastEventData] = emittedEvents[1];

        expect(lastEventData).toEqual({
          addProjects: [],
          removeProjects: [getIdFromGraphQLId(mockProjects[4].id)],
        });
      });

      it('emits update:projects event when all projects are selected and deselected', async () => {
        await findSelectAllCheckbox().setChecked(true);
        await nextTick();

        const selectEmittedEvents = wrapper.emitted('update:projects');
        const lastSelectEvent = selectEmittedEvents[selectEmittedEvents.length - 1][0];

        const totalProjects = wrapper.findAll('tbody > tr').length;
        expect(lastSelectEvent.addProjects).toHaveLength(totalProjects);
        expect(lastSelectEvent.removeProjects).toHaveLength(0);

        await findSelectAllCheckbox().setChecked(false);
        await nextTick();

        const allEmittedEvents = wrapper.emitted('update:projects');
        const lastDeselectEvent = allEmittedEvents[allEmittedEvents.length - 1][0];
        expect(lastDeselectEvent.removeProjects).toHaveLength(totalProjects);
        expect(lastDeselectEvent.addProjects).toHaveLength(0);
      });

      it('correctly handles indeterminate state of select all checkbox', async () => {
        createComponent();
        await waitForPromises();

        await findCheckbox(1).setChecked(true);
        await nextTick();

        expect(wrapper.vm.pageAllSelectedIndeterminate).toBe(true);

        const selectAllCheckboxElement = findSelectAllCheckbox().element;
        expect(selectAllCheckboxElement.indeterminate).toBe(true);
        expect(selectAllCheckboxElement.checked).toBe(false);
      });

      it('correctly selects all when some projects are already selected', async () => {
        createComponent();
        await waitForPromises();

        await findCheckbox(1).setChecked(true);
        await nextTick();

        await findSelectAllCheckbox().setChecked(true);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        const lastEvent = emittedEvents[emittedEvents.length - 1][0];

        expect(lastEvent.addProjects).toHaveLength(mockProjects.length);
        expect(lastEvent.removeProjects).toHaveLength(0);
      });

      it('correctly handles toggling selection multiple times', async () => {
        createComponent();
        await waitForPromises();

        await findCheckbox(1).setChecked(false);
        await nextTick();

        await findCheckbox(1).setChecked(true);
        await nextTick();

        await findCheckbox(1).setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(3);

        const lastEvent = emittedEvents[emittedEvents.length - 1][0];
        const projectId = getIdFromGraphQLId(mockProjects[1].id);

        expect(lastEvent.addProjects).not.toContain(projectId);
        expect(lastEvent.removeProjects).toContain(projectId);
      });

      it('preserves selected items when navigating between pages', async () => {
        const initialResponse = {
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              projects: {
                nodes: mockProjects,
                pageInfo: {
                  hasNextPage: true,
                  hasPreviousPage: false,
                  startCursor: 'start123',
                  endCursor: 'end123',
                  __typename: 'PageInfo',
                },
              },
            },
          },
        };

        createComponent({
          resolverMock: jest.fn().mockResolvedValue(initialResponse),
        });
        await waitForPromises();
        await nextTick();

        const pagination = findPagination();
        expect(pagination.exists()).toBe(true);
        expect(pagination.props('pageInfo')).toEqual(initialResponse.data.group.projects.pageInfo);

        await findCheckbox(1).setChecked(true);
        await nextTick();

        const nextPageResponse = {
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              projects: {
                nodes: Array.from({ length: 5 }, (_, id) =>
                  createProject({ id: id + 5, groupPath: 'foo' }),
                ),
                pageInfo: {
                  hasNextPage: false,
                  hasPreviousPage: true,
                  startCursor: 'start456',
                  endCursor: 'end456',
                  __typename: 'PageInfo',
                },
              },
            },
          },
        };

        const fetchMoreSpy = jest.spyOn(wrapper.vm.$apollo.queries.projectList, 'fetchMore');
        fetchMoreSpy.mockImplementation(({ updateQuery }) =>
          updateQuery({}, { fetchMoreResult: nextPageResponse }),
        );

        await pagination.vm.$emit('next', 'end123');
        await waitForPromises();
        await nextTick();

        const firstPageResponse = {
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              projects: {
                nodes: mockProjects,
                pageInfo: {
                  hasNextPage: true,
                  hasPreviousPage: false,
                  startCursor: 'start123',
                  endCursor: 'end123',
                  __typename: 'PageInfo',
                },
              },
            },
          },
        };

        fetchMoreSpy.mockImplementation(({ updateQuery }) =>
          updateQuery({}, { fetchMoreResult: firstPageResponse }),
        );

        await pagination.vm.$emit('prev', 'start456');
        await waitForPromises();
        await nextTick();

        expect(wrapper.vm.projectSelected(mockProjects[1].id)).toBe(true);
      });

      describe('selectAllOnPageDisabled', () => {
        it('returns true when projectList is empty', async () => {
          createComponent({
            resolverMock: jest.fn().mockResolvedValue({
              data: {
                group: {
                  id: 'gid://gitlab/Group/1',
                  projects: {
                    nodes: [],
                    pageInfo: {
                      hasNextPage: false,
                      hasPreviousPage: false,
                      startCursor: null,
                      endCursor: null,
                      __typename: 'PageInfo',
                    },
                  },
                },
              },
            }),
          });
          await waitForPromises();
          await nextTick();

          expect(wrapper.vm.selectAllOnPageDisabled).toBe(true);
          expect(findSelectAllCheckbox().attributes('disabled')).toBe('disabled');
        });

        it('returns false when projectList has items', async () => {
          createComponent();
          await waitForPromises();
          await nextTick();

          expect(wrapper.vm.selectAllOnPageDisabled).toBe(false);
          expect(findSelectAllCheckbox().attributes('disabled')).toBeUndefined();
        });
      });

      describe('hasFilters', () => {
        it('returns true when filters array has items', async () => {
          createComponent();
          await waitForPromises();
          await nextTick();

          wrapper.vm.filters = [
            { type: 'project', value: { data: 'test-project', operator: 'matches' } },
            { type: 'framework', value: { data: 'test-framework', operator: '=' } },
          ];
          await nextTick();

          expect(wrapper.vm.hasFilters).toBe(true);
        });

        it('returns false when filters array is empty', async () => {
          createComponent();
          await waitForPromises();
          await nextTick();

          wrapper.vm.filters = [];
          await nextTick();

          expect(wrapper.vm.hasFilters).toBe(false);
        });
      });

      describe('noProjectsText', () => {
        it('returns noProjectsSelected when selected only toggle is active', async () => {
          createComponent();
          await waitForPromises();
          await findShowOnlySelectedToggle().vm.$emit('change', true);
          await nextTick();
          expect(wrapper.vm.noProjectsText).toBe(i18n.noProjectsSelected);
        });

        it('returns noProjectsFoundMatchingFilters when filters are applied', async () => {
          createComponent();
          await waitForPromises();
          await nextTick();

          wrapper.vm.filters = [
            { type: 'project', value: { data: 'test-project', operator: 'matches' } },
          ];
          await nextTick();

          expect(wrapper.vm.noProjectsText).toBe(i18n.noProjectsFoundMatchingFilters);
        });

        it('returns noProjectsFound when no filters are applied', async () => {
          createComponent();
          await waitForPromises();
          await nextTick();

          wrapper.vm.filters = [];
          await nextTick();

          expect(wrapper.vm.noProjectsText).toBe(i18n.noProjectsFound);
        });
      });
    });

    describe('computed properties', () => {
      it('correctly displays associated projects', () => {
        const projectRows = wrapper.findAll('tbody > tr');
        expect(projectRows).toHaveLength(5);

        projects.forEach((project, index) => {
          const projectName = findTableRowData(index).at(1).text();
          expect(projectName).toContain(project.name);
        });
      });

      it('correctly displays non-associated projects', () => {
        const projectRows = wrapper.findAll('tbody > tr');

        mockProjects.forEach((project) => {
          const projectRow = projectRows.wrappers.find((row) => row.text().includes(project.name));
          expect(projectRow).toBeDefined();
        });
      });
    });

    describe('selectedCount', () => {
      const findSelectedCount = () => wrapper.findByTestId('selected-count');
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('returns initial count when no changes are made', () => {
        expect(findSelectedCount().text()).toBe('3');
      });

      it('increases count when a new project is added', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();

        expect(findSelectedCount().text()).toBe('4');
      });

      it('decreases count when an existing project is removed', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();
        expect(findSelectedCount().text()).toBe('4');

        await findCheckbox(0).setChecked(false);
        await nextTick();

        expect(findSelectedCount().text()).toBe('3');
      });

      it('handles adding and removing the same project', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();
        expect(findSelectedCount().text()).toBe('4');

        await findCheckbox(4).setChecked(false);
        await nextTick();

        expect(findSelectedCount().text()).toBe('3');
      });

      it('handles multiple additions and removals', async () => {
        await findCheckbox(3).setChecked(true);
        await findCheckbox(4).setChecked(true);
        await nextTick();
        expect(findSelectedCount().text()).toBe('5');

        await findCheckbox(4).setChecked(false);
        await findCheckbox(0).setChecked(false);
        await nextTick();

        expect(findSelectedCount().text()).toBe('3');
      });

      it('handles select all and deselect all', async () => {
        await findSelectAllCheckbox().setChecked(true);
        await nextTick();
        expect(findSelectedCount().text()).toBe('5'); // all mock projects

        await findSelectAllCheckbox().setChecked(false);
        await nextTick();

        expect(findSelectedCount().text()).toBe('0');
      });
    });

    describe('showOnlySelected toggle', () => {
      const findProjectRows = () => wrapper.findAll('tbody > tr');

      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders the toggle with correct initial state', () => {
        const toggle = findShowOnlySelectedToggle();
        expect(toggle.exists()).toBe(true);
        expect(toggle.props('value')).toBe(false);
        expect(toggle.props('label')).toBe(i18n.showOnlySelected);
        expect(toggle.props('labelPosition')).toBe('left');
      });

      it('shows all projects when toggle is off', () => {
        expect(findProjectRows()).toHaveLength(5);
      });

      it('shows only selected projects when toggle is on', async () => {
        await findShowOnlySelectedToggle().vm.$emit('change', true);
        await nextTick();
        expect(queryMock).toHaveBeenCalledWith({
          first: 20,
          frameworks: ['gid://gitlab/ComplianceManagement::Framework/1'],
          frameworksNot: [],
          groupPath: 'gitlab-org',
        });
      });
    });
  });

  describe('error handling', () => {
    it('handles Apollo query errors', async () => {
      const error = new Error('GraphQL Error');
      createComponent({
        resolverMock: jest.fn().mockRejectedValue(error),
      });

      await waitForPromises();
      await nextTick();

      const errorMessage = wrapper.findByText(/error/i);
      expect(errorMessage.exists()).toBe(true);

      const projectRows = wrapper.findAll('tbody > tr');
      expect(projectRows).toHaveLength(0);
    });
  });

  describe('pagination', () => {
    describe('when there are projects to paginate', () => {
      const mockPageInfo = {
        hasNextPage: true,
        hasPreviousPage: true,
        startCursor: 'start123',
        endCursor: 'end123',
        __typename: 'PageInfo',
      };

      let mock;

      const lotsOfProjects = Array.from({ length: 51 }, (_, id) =>
        createProject({ id, groupPath: 'foo' }),
      );

      beforeEach(async () => {
        mock = jest.fn().mockResolvedValue({
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              projects: {
                nodes: lotsOfProjects,
                pageInfo: mockPageInfo,
              },
            },
          },
        });

        createComponent({
          resolverMock: mock,
        });

        await waitForPromises();
        await nextTick();
      });

      it('displays pagination component when pageInfo is available', () => {
        const pagination = findPagination();
        expect(pagination.exists()).toBe(true);
        expect(pagination.props('pageInfo')).toEqual({
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'start123',
          endCursor: 'end123',
          __typename: 'PageInfo',
        });
        expect(pagination.props('perPage')).toBe(20);
        expect(pagination.props('isLoading')).toBe(false);
      });

      it('calls query with correct variables when navigating to next page', async () => {
        await findPagination().vm.$emit('next', 'end123');

        expect(mock).toHaveBeenCalledWith({
          groupPath: 'gitlab-org',
          first: 20,
          after: 'end123',
          last: null,
          before: null,
          frameworks: [],
          frameworksNot: [],
        });
      });

      it('calls query with correct variables when navigating to previous page', async () => {
        await findPagination().vm.$emit('prev', 'start123');

        expect(mock).toHaveBeenCalledWith({
          groupPath: 'gitlab-org',
          first: null,
          after: null,
          last: 20,
          before: 'start123',
          frameworks: [],
          frameworksNot: [],
        });
      });

      it('shows loading state during pagination navigation', async () => {
        createComponent({
          resolverMock: jest.fn().mockResolvedValue({
            data: {
              group: {
                id: 'gid://gitlab/Group/1',
                projects: {
                  nodes: mockProjects,
                  pageInfo: {
                    hasNextPage: true,
                    hasPreviousPage: false,
                    startCursor: 'start123',
                    endCursor: 'end123',
                    __typename: 'PageInfo',
                  },
                },
              },
            },
          }),
        });
        await waitForPromises();
        await nextTick();

        await nextTick();

        await findPagination().vm.$emit('next', 'end123');

        expect(findPagination().props('isLoading')).toBe(true);
        expect(mock).toHaveBeenCalled();
      });
    });

    describe('when there are not enough projects to paginate', () => {
      it('does not display pagination when there are no projects', async () => {
        createComponent({
          resolverMock: jest.fn().mockResolvedValue({
            data: {
              group: {
                id: 'gid://gitlab/Group/1',
                projects: {
                  nodes: [],
                  pageInfo: {
                    hasNextPage: false,
                    hasPreviousPage: false,
                    startCursor: null,
                    endCursor: null,
                  },
                },
              },
            },
          }),
        });

        await waitForPromises();

        expect(findPagination().exists()).toBe(false);
      });

      it('does not display pagination when there are not enough projects to paginate', async () => {
        const fewProjects = Array.from({ length: 10 }, (_, id) =>
          createProject({ id, groupPath: 'foo' }),
        );

        createComponent({
          resolverMock: jest.fn().mockResolvedValue({
            data: {
              group: {
                id: 'gid://gitlab/Group/1',
                projects: {
                  nodes: fewProjects,
                  pageInfo: {
                    hasNextPage: false,
                    hasPreviousPage: false,
                    startCursor: null,
                    endCursor: null,
                  },
                },
              },
            },
          }),
        });

        await waitForPromises();

        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('filters', () => {
    const findFilters = () => wrapper.findComponent(Filters);

    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the filters component', () => {
      expect(findFilters().exists()).toBe(true);
    });

    it('passes the correct props to the filters component', () => {
      const filters = findFilters();
      expect(filters.props('value')).toEqual([]);
      expect(filters.props('groupPath')).toBe('gitlab-org');
      expect(filters.props('error')).toBeUndefined();
      expect(filters.props('showUpdatePopover')).toBe(false);
    });

    it('updates query variables when filters change', async () => {
      const newFilters = [
        {
          type: 'project',
          value: { data: 'test-project', operator: 'matches' },
        },
        {
          type: 'framework',
          value: { data: 'test-framework', operator: '=' },
        },
      ];

      wrapper.vm.onFiltersChanged(newFilters);
      await nextTick();

      expect(wrapper.vm.queryVariables).toEqual({
        groupPath: 'gitlab-org',
        first: 20,
        frameworks: ['test-framework'],
        frameworksNot: [],
        project: 'test-project',
      });
    });

    it('handles framework exclusion filters correctly', async () => {
      const newFilters = [
        {
          type: 'framework',
          value: { data: 'excluded-framework', operator: '!=' },
        },
      ];

      wrapper.vm.onFiltersChanged(newFilters);
      await nextTick();

      expect(wrapper.vm.queryVariables).toEqual({
        groupPath: 'gitlab-org',
        first: 20,
        frameworks: [],
        frameworksNot: ['excluded-framework'],
      });
    });

    it('handles group filters correctly', async () => {
      const newFilters = [
        {
          type: 'groupPath',
          value: { data: 'test-group', operator: 'matches' },
        },
      ];

      wrapper.vm.onFiltersChanged(newFilters);
      await nextTick();

      expect(wrapper.vm.queryVariables).toEqual({
        groupPath: 'test-group',
        first: 20,
        frameworks: [],
        frameworksNot: [],
      });
    });

    it('handles multiple filters of different types', async () => {
      const newFilters = [
        {
          type: 'project',
          value: { data: 'test-project', operator: 'matches' },
        },
        {
          type: 'framework',
          value: { data: 'included-framework', operator: '=' },
        },
        {
          type: 'framework',
          value: { data: 'excluded-framework', operator: '!=' },
        },
        {
          type: 'groupPath',
          value: { data: 'test-group', operator: 'matches' },
        },
      ];

      wrapper.vm.onFiltersChanged(newFilters);
      await nextTick();

      expect(wrapper.vm.queryVariables).toEqual({
        groupPath: 'test-group',
        first: 20,
        frameworks: ['included-framework'],
        frameworksNot: ['excluded-framework'],
        project: 'test-project',
      });
    });
  });
});
