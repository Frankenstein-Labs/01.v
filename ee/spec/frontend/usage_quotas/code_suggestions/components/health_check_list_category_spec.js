import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { probesByCategory } from 'ee/usage_quotas/code_suggestions/utils';
import HealthCheckListCategory from 'ee/usage_quotas/code_suggestions/components/health_check_list_category.vue';
import HealthCheckListProbe from 'ee/usage_quotas/code_suggestions/components/health_check_list_probe.vue';

import {
  MOCK_NETWORK_PROBES,
  MOCK_SYNCHRONIZATION_PROBES,
  MOCK_SYSTEM_EXCHANGE_PROBES,
} from '../mock_data';

describe('Health Check List Category', () => {
  let wrapper;

  const MOCK_PROBES_BY_CATEGORY = [
    ...MOCK_NETWORK_PROBES.success,
    ...MOCK_SYNCHRONIZATION_PROBES.success,
    ...MOCK_SYSTEM_EXCHANGE_PROBES.success,
  ];

  const defaultProps = {
    category: probesByCategory(MOCK_PROBES_BY_CATEGORY)[0],
  };

  const findAllHealthCheckProbes = () => wrapper.findAllComponents(HealthCheckListProbe);

  const createComponent = () => {
    wrapper = shallowMountExtended(HealthCheckListCategory, {
      propsData: {
        ...defaultProps,
      },
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the category title', () => {
      expect(wrapper.findByText(defaultProps.category.title).exists()).toBe(true);
    });

    it('renders the category description', () => {
      expect(wrapper.findByText(defaultProps.category.description).exists()).toBe(true);
    });

    it('renders a probe item for each probe in the category', () => {
      expect(findAllHealthCheckProbes().wrappers.map((w) => w.props('probe'))).toStrictEqual(
        defaultProps.category.probes,
      );
    });
  });
});
