import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RunnerDashboardLink from 'ee_component/ci/runner/components/runner_dashboard_link.vue';

import { runnerDashboardPath } from 'ee_jest/ci/runner/mock_data';

describe('RunnerDashboardLink', () => {
  let wrapper;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = (options) => {
    wrapper = shallowMountExtended(RunnerDashboardLink, {
      ...options,
    });
  };

  describe('when runnerDashboardPath is available', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          runnerDashboardPath,
        },
      });
    });

    it('renders button', () => {
      expect(findButton().text()).toContain('Fleet dashboard');
      expect(findButton().props('variant')).toBe('link');
      expect(findButton().attributes('href')).toBe(runnerDashboardPath);
    });
  });

  describe('when runnerDashboardPath is not available', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render', () => {
      expect(findButton().exists()).toBe(false);
    });
  });
});
