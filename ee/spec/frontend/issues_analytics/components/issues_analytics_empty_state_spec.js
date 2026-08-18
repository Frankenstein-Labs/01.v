import { GlEmptyState } from '@gitlab/ui';
import IssuesAnalyticsEmptyState from 'ee/issues_analytics/components/issues_analytics_empty_state.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithoutAnyIssues from '~/work_items/list/components/empty_state_without_any_issues.vue';

describe('IssuesAnalyticsEmptyState', () => {
  let wrapper;

  const svgHeight = 150;
  const mockNoDataWithFiltersSvgPath = 'no-data-with-filters.svg';
  const mockNoDataWithFiltersEmptyState = {
    title: 'Sorry, your filter produced no results',
    description: 'To widen your search, change or remove filters in the filter bar above.',
    svgPath: mockNoDataWithFiltersSvgPath,
    svgHeight,
  };
  const defaultProvide = {
    showNewIssueDropdown: true,
    filtersEmptyStateSvgPath: mockNoDataWithFiltersSvgPath,
  };

  const createComponent = ({ props = {}, provide = defaultProvide } = {}) => {
    wrapper = shallowMountExtended(IssuesAnalyticsEmptyState, {
      propsData: {
        ...props,
      },
      provide,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findEmptyStateWithoutAnyIssues = () => wrapper.findComponent(EmptyStateWithoutAnyIssues);

  describe('No data with filters', () => {
    beforeEach(() => {
      createComponent({ props: { emptyStateType: 'noDataWithFilters' } });
    });

    it('should render the correct empty state type', () => {
      expect(findEmptyState().props()).toMatchObject(mockNoDataWithFiltersEmptyState);
    });

    it('should not render the EmptyStateWithoutAnyIssues component', () => {
      expect(findEmptyStateWithoutAnyIssues().exists()).toBe(false);
    });
  });

  describe('No data', () => {
    beforeEach(() => {
      createComponent({ props: { emptyStateType: 'noData' } });
    });

    it('should render the empty state without any issues', () => {
      expect(findEmptyStateWithoutAnyIssues().exists()).toBe(true);
    });

    it('should not render the generic empty state component', () => {
      expect(findEmptyState().exists()).toBe(false);
    });
  });
});
