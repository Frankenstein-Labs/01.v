import { GlCollapsibleListbox } from '@gitlab/ui';
import VisualizationFilters from 'ee/usage_quotas/pipelines/admin/components/shared/visualization_filters.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockRunnerFilters } from '../../mock_data';

describe('VisualizationFilters', () => {
  let wrapper;
  const defaultProps = {
    runners: mockRunnerFilters.data.ciDedicatedHostedRunnerFilters.runners.nodes.map((runner) => {
      return {
        text: `${runner.id} - ${runner.description}`,
        value: runner.id,
      };
    }),
  };

  const findRunnerFilterDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(VisualizationFilters, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('rendering', () => {
    it('renders runner filter', () => {
      createComponent();

      expect(findRunnerFilterDropdown().exists()).toBe(true);
    });
  });

  describe('selecting a runner', () => {
    const selectedOption = 'gid://gitlab/Ci::Runner/60';

    beforeEach(() => {
      createComponent();
    });

    it('emits a runner-selected event with the runner value', () => {
      findRunnerFilterDropdown().vm.$emit('select', selectedOption);

      expect(wrapper.emitted('runner-selected')).toEqual([[selectedOption]]);
    });
  });
});
