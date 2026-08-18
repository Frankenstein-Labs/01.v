import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf, GlLink, GlAlert, GlLoadingIcon, GlKeysetPagination } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';
import StandardsAdherenceTableV2 from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table_v2.vue';
import DetailsDrawer from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/details_drawer.vue';
import GroupedTable from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_table.vue';
import FiltersBar from 'ee/compliance_dashboard/components/standards_adherence_report/components/filters_bar/filters_bar.vue';
import { GroupedLoader } from 'ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader';
import { GRAPHQL_FIELD_MISSING_ERROR_MESSAGE } from 'ee/compliance_dashboard/constants';
import { isGraphqlFieldMissingError } from 'ee/compliance_dashboard/utils';

jest.mock('ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader');
jest.mock('ee/compliance_dashboard/utils');

Vue.use(VueApollo);

describe('StandardsAdherenceTableV2', () => {
  let wrapper;

  const findGroupedTable = () => wrapper.findComponent(GroupedTable);
  const findDetailsDrawer = () => wrapper.findComponent(DetailsDrawer);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyText = () => wrapper.findComponent(GlSprintf);
  const findEmptyLink = () => wrapper.findComponent(GlLink);
  const findFiltersBar = () => wrapper.findComponent(FiltersBar);
  const findPageSizeSelector = () => wrapper.findComponent(PageSizeSelector);

  const waitForNextPageLoad = async () => {
    // triggers loading state
    await nextTick();
    // wait for resolve
    await waitForPromises();
    // render
    await nextTick();
    // extra tick for Vue.js 3
    await nextTick();
  };

  const groupPath = 'group/path';
  const mockItems = {
    data: [
      {
        group: null,
        children: [
          { id: '1', name: 'Requirement 1' },
          { id: '2', name: 'Requirement 2' },
        ],
      },
    ],
    pageInfo: { hasNextPage: false },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(StandardsAdherenceTableV2, {
      propsData: {
        groupPath,
        ...props,
      },
      apolloProvider: createMockApollo(),
      stubs: {
        GlLink,
        GlSprintf,
      },
    });
  };

  function createMockLoader(overrides = {}) {
    return function mockedGroupLoader() {
      this.loadPage = overrides.loadPage ?? jest.fn().mockResolvedValue(mockItems);
      this.loadNextPage =
        overrides.loadNextPage ??
        jest.fn().mockResolvedValue({
          data: [{ group: null, children: [{ id: '3', name: 'Requirement 3' }] }],
          pageInfo: { hasNextPage: false, hasPreviousPage: true },
        });
      this.loadPrevPage = overrides.loadPrevPage ?? jest.fn().mockResolvedValue(mockItems);
      this.setPageSize = overrides.setPageSize ?? jest.fn();
    };
  }

  beforeEach(() => {
    GroupedLoader.mockClear();
    // Mock the GroupedLoader implementation
    GroupedLoader.mockImplementation(createMockLoader());
  });

  describe('initialization', () => {
    it('renders loading state', () => {
      createComponent();
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findGroupedTable().exists()).toBe(false);
    });

    describe('initializes GroupedLoader with correct parameters', () => {
      it('for group', () => {
        createComponent();
        expect(GroupedLoader).toHaveBeenCalledWith({
          fullPath: groupPath,
          apollo: expect.any(Object),
          mode: 'group',
        });
        expect(GroupedLoader.mock.instances.at(-1).loadPage).toHaveBeenCalled();
      });

      it('for project', () => {
        const projectPath = 'project/path';
        createComponent({ projectPath });

        expect(GroupedLoader).toHaveBeenCalledWith({
          fullPath: projectPath,
          apollo: expect.any(Object),
          mode: 'project',
        });
        expect(GroupedLoader.mock.instances.at(-1).loadPage).toHaveBeenCalled();
      });
    });
  });

  describe('after data is loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays GroupedTable', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findGroupedTable().exists()).toBe(true);
    });

    it('passes items data to GroupedTable', () => {
      expect(findGroupedTable().props('items')).toEqual(mockItems.data);
    });

    describe('row selection', () => {
      const selectedItem = { id: '1', name: 'Selected Item' };

      it('updates selectedStatus when a row is selected', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);
      });

      it('does not update selectedStatus when the same row is selected again', async () => {
        // First selection
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);

        // Select the same item again
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);
      });

      it('passes selected status to details drawer', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);
      });

      it('clears selected status when DetailsDrawer emits close', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();

        findDetailsDrawer().vm.$emit('close');
        await nextTick();

        expect(findDetailsDrawer().props('status')).toBe(null);
      });
    });
  });

  describe('error handling', () => {
    it('sets generic error message when fetch fails', async () => {
      GroupedLoader.mockImplementation(
        createMockLoader({
          loadPage: jest.fn().mockRejectedValue(new Error('Network error')),
        }),
      );

      createComponent();

      // one tick to trigger load (double for Vue.js 3)
      await nextTick();
      await nextTick();
      // and another to display failure
      await nextTick();
      await nextTick();

      expect(findAlert().text()).toContain('There was an error');
    });

    it('sets specific error message for GraphQL field missing error', async () => {
      const error = new Error('GraphQL error');
      isGraphqlFieldMissingError.mockReturnValue(true);

      GroupedLoader.mockImplementation(
        createMockLoader({
          loadPage: jest.fn().mockRejectedValue(error),
        }),
      );

      createComponent();

      // one tick to trigger load (double for Vue.js 3)
      await nextTick();
      await nextTick();
      // and another to display failure
      await nextTick();
      await nextTick();

      expect(isGraphqlFieldMissingError).toHaveBeenCalledWith(
        error,
        'projectComplianceRequirementsStatus',
      );
      expect(findAlert().text()).toContain(GRAPHQL_FIELD_MISSING_ERROR_MESSAGE);
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      GroupedLoader.mockImplementation(createMockLoader());
      createComponent();
      return nextTick();
    });

    const findPagination = () => wrapper.findComponent(GlKeysetPagination);

    it('displays pagination component when pageInfo is available', () => {
      expect(findPagination().exists()).toBe(true);
    });

    it('loads next page when next is clicked', async () => {
      findPagination().vm.$emit('next');

      expect(GroupedLoader.mock.instances[0].loadNextPage).toHaveBeenCalled();

      await waitForNextPageLoad();

      expect(findGroupedTable().props('items')).toEqual([
        { group: null, children: [{ id: '3', name: 'Requirement 3' }] },
      ]);
    });

    it('loads previous page when prev is clicked', async () => {
      findPagination().vm.$emit('prev');

      expect(GroupedLoader.mock.instances[0].loadPrevPage).toHaveBeenCalled();

      await waitForNextPageLoad();

      expect(findGroupedTable().props('items')).toEqual(mockItems.data);
    });

    it('updates page size and reloads data when page size changes', async () => {
      const newPageSize = 50;
      findPageSizeSelector().vm.$emit('input', newPageSize);

      expect(GroupedLoader.mock.instances[0].setPageSize).toHaveBeenCalledWith(newPageSize);
      expect(GroupedLoader.mock.instances[0].loadPage).toHaveBeenCalled();

      await waitForNextPageLoad();
      expect(wrapper.findComponent(PageSizeSelector).props('value')).toBe(newPageSize);
    });

    it('shows PageSizeSelector when groupBy is not set', () => {
      expect(findPageSizeSelector().exists()).toBe(true);
    });

    it('hides PageSizeSelector when groupBy is set', async () => {
      findFiltersBar().vm.$emit('update:groupBy', 'project');
      await nextTick();

      expect(findPageSizeSelector().exists()).toBe(false);
    });
  });

  describe('filters', () => {
    beforeEach(() => {
      GroupedLoader.mockImplementation(createMockLoader());
    });

    it('passes the filters to the GroupedLoader when they change', async () => {
      createComponent();
      await nextTick();
      const newFilters = { projectId: 123 };

      // Find the filters bar component and emit the updated filters
      const filtersBar = wrapper.findComponent(FiltersBar);
      filtersBar.vm.$emit('update:filters', newFilters);
      await nextTick();

      expect(GroupedLoader.mock.instances[0].setFilters).toHaveBeenCalledWith(newFilters);
      expect(GroupedLoader.mock.instances[0].loadPage).toHaveBeenCalled();
    });

    describe('correctly sets with-projects', () => {
      it('for group', async () => {
        createComponent();
        await nextTick();

        const filtersBar = wrapper.findComponent(FiltersBar);
        expect(filtersBar.props('withProjects')).toBe(true);
      });

      it('for project', async () => {
        createComponent({ projectPath: 'test-project' });
        await nextTick();

        const filtersBar = wrapper.findComponent(FiltersBar);
        expect(filtersBar.props('withProjects')).toBe(false);
      });
    });
  });

  describe('empty state', () => {
    const emptyItems = {
      data: [{ group: null, children: [] }],
      pageInfo: { hasNextPage: false },
    };

    beforeEach(async () => {
      GroupedLoader.mockImplementation(function mockGroupedLoader() {
        this.loadPage = jest.fn().mockResolvedValue(emptyItems);
      });

      createComponent();
      await waitForPromises();
      await nextTick();
      await nextTick();
    });

    it('displays empty state message when no items', () => {
      expect(wrapper.text()).toContain('No statuses found.');
    });

    it('displays help text with link in empty state', () => {
      expect(findEmptyText().exists()).toBe(true);
      expect(wrapper.text()).toContain('To show a status here, you must');
    });

    it('displays correct link in empty state', () => {
      expect(findEmptyLink().attributes('href')).toBe(
        '/user/compliance/compliance_frameworks/_index',
      );
      expect(findEmptyLink().attributes('anchor')).toBe('requirements');
      expect(findEmptyLink().attributes('target')).toBe('_blank');
    });

    it('does not display GroupedTable in empty state', () => {
      expect(findGroupedTable().exists()).toBe(false);
    });

    it('does not display pagination in empty state', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });
  });

  describe('groupBy functionality', () => {
    beforeEach(() => {
      GroupedLoader.mockImplementation(createMockLoader());
      createComponent();
    });

    it('updates groupBy when groupBy changes', async () => {
      const newGroupBy = 'project';
      findFiltersBar().vm.$emit('update:groupBy', newGroupBy);
      await nextTick();

      expect(GroupedLoader.mock.instances[0].setGroupBy).toHaveBeenCalledWith(newGroupBy);
      expect(GroupedLoader.mock.instances[0].loadPage).toHaveBeenCalled();
    });

    it('sets loading state when groupBy changes', async () => {
      await nextTick();

      const newGroupBy = 'project';
      findFiltersBar().vm.$emit('update:groupBy', newGroupBy);
      await nextTick();
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('passes groupBy to GroupedTable', async () => {
      const newGroupBy = 'project';
      findFiltersBar().vm.$emit('update:groupBy', newGroupBy);
      await nextTick();
      await waitForNextPageLoad();

      expect(findGroupedTable().props('groupBy')).toBe(newGroupBy);
    });
  });
});
