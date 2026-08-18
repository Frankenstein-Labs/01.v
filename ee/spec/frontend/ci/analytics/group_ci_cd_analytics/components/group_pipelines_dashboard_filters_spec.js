import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupPipelinesDashboardFilters from 'ee/ci/analytics/group_ci_cd_analytics/components/group_pipelines_dashboard_filters.vue';
import DateRangeFilter from '~/ci/analytics/components/date_range_filter.vue';

describe('GroupPipelinesDashboardFilters', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GroupPipelinesDashboardFilters, {
      propsData: {
        ...props,
      },
    });
  };

  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes null as the selected value', () => {
      expect(findDateRangeFilter().props('selected')).toBe(null);
    });
  });

  describe('when value prop is provided', () => {
    beforeEach(() => {
      createComponent({ value: { dateRange: '30d' } });
    });

    it('passes dateRange to the date range filter', () => {
      expect(findDateRangeFilter().props('selected')).toBe('30d');
    });
  });

  describe('when date range is selected', () => {
    beforeEach(() => {
      createComponent({ value: { dateRange: '7d' } });
      findDateRangeFilter().vm.$emit('select', '90d');
    });

    it('emits input event with updated dateRange', () => {
      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0][0]).toEqual({ dateRange: '90d' });
    });
  });

  describe('when value prop changes', () => {
    beforeEach(async () => {
      createComponent({ value: { dateRange: '7d' } });
      await wrapper.setProps({ value: { dateRange: '180d' } });
    });

    it('updates the selected date range', () => {
      expect(findDateRangeFilter().props('selected')).toBe('180d');
    });
  });
});
