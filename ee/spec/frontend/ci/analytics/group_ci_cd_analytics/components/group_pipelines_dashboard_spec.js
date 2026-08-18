import { GlDashboardLayout } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { useFakeDate } from 'helpers/fake_date';
import GroupPipelinesDashboard from 'ee/ci/analytics/group_ci_cd_analytics/components/group_pipelines_dashboard.vue';
import GroupDashboardFilters from 'ee/ci/analytics/group_ci_cd_analytics/components/group_pipelines_dashboard_filters.vue';
import { updateQueryHistory } from '~/ci/analytics/url_utils';

jest.mock('~/ci/analytics/url_utils', () => ({
  ...jest.requireActual('~/ci/analytics/url_utils'),
  updateQueryHistory: jest.fn(),
}));

describe('GroupPipelinesDashboard', () => {
  useFakeDate('2026-02-01T10:00');

  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(GroupPipelinesDashboard);
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findFilters = () => wrapper.findComponent(GroupDashboardFilters);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the dashboard layout', () => {
      expect(findDashboardLayout().exists()).toBe(true);
      expect(findFilters().exists()).toBe(true);
    });

    it('passes the default params to the filters', () => {
      expect(findFilters().props('value')).toEqual(
        expect.objectContaining({
          dateRange: '7d',
        }),
      );
    });

    it('computes variables with date range', () => {
      // TODO This is a temporary test, will replace with actual data when we add backend queries
      expect(wrapper.vm.variables).toEqual({
        fromTime: new Date('2026-01-25'),
        toTime: new Date('2026-02-01'),
      });
    });
  });

  describe('when filters emit input', () => {
    beforeEach(() => {
      createComponent();

      findFilters().vm.$emit('input', { dateRange: '30d' });
    });

    it('updates params', () => {
      expect(findFilters().props('value')).toEqual({
        dateRange: '30d',
      });
    });

    it('updates the query history', () => {
      expect(updateQueryHistory).toHaveBeenCalledWith({ dateRange: '30d' }, { dateRange: '7d' });
    });

    it('computes variables for the selected date range', () => {
      // TODO This is a temporary test, will replace with actual data when we add backend queries
      expect(wrapper.vm.variables).toEqual({
        fromTime: new Date('2026-01-02'),
        toTime: new Date('2026-02-01'),
      });
    });
  });

  describe('when URL contains a date range query parameter', () => {
    beforeEach(() => {
      setWindowLocation(`${TEST_HOST}/?time=90d`);
      createComponent();
    });

    it('initializes params from the URL', () => {
      expect(findFilters().props('value')).toEqual({
        dateRange: '90d',
      });
    });

    it('computes variables for the URL date range', () => {
      // TODO This is a temporary test, will replace with actual data when we add backend queries
      expect(wrapper.vm.variables).toEqual({
        fromTime: new Date('2025-11-03'),
        toTime: new Date('2026-02-01'),
      });
    });
  });
});
