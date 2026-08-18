import { GlSingleStat } from '@gitlab/ui/src/charts';
import RunnerUsageHeader from 'ee/usage_quotas/pipelines/admin/components/runner_usage_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('RunnerUsageHeader', () => {
  let wrapper;
  const defaultProps = {
    monthlyUsage: 200,
    loading: false,
  };

  const findHostedRunnerMonthlyUsage = () => wrapper.findByTestId('hosted-runner-monthly-usage');
  const findSubtitle = () => wrapper.findByTestId('overview-subtitle');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(RunnerUsageHeader, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSingleStat,
      },
    });
  };

  describe('rendering after loading', () => {
    it('renders monthly hosted runner usage', () => {
      createComponent();

      expect(findSubtitle().text()).toBe('Hosted runner usage');
      expect(findHostedRunnerMonthlyUsage().text()).toBe('Usage this month 200 minutes');
    });
  });
});
