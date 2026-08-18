import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DoraProjectsComparison from 'ee/analytics/analytics_dashboards/components/visualizations/dora_projects_comparison.vue';
import ComparisonTable from 'ee/analytics/dashboards/dora_projects_comparison/components/comparison_table.vue';
import { mockProjectsDoraMetrics } from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';

describe('DoraProjectsComparison Visualization', () => {
  let wrapper;

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMountExtended(DoraProjectsComparison, { propsData });
  };

  const findComparisonTable = () => wrapper.findComponent(ComparisonTable);

  beforeEach(() => {
    createWrapper({
      data: mockProjectsDoraMetrics,
    });
  });

  it('renders the comparison table', () => {
    expect(findComparisonTable().props().projects).toEqual(mockProjectsDoraMetrics);
  });
});
