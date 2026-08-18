import { cloneDeep } from 'lodash-es';
import MinutesUsagePerProject from 'ee/usage_quotas/pipelines/namespace/components/minutes_usage_per_project.vue';
import NoMinutesAlert from 'ee/usage_quotas/pipelines/namespace/components/no_minutes_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockGetProjectsCiMinutesUsage } from '../mock_data';

describe('MinutesUsagePerProject', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const defaultProps = {
    projects: cloneDeep(mockGetProjectsCiMinutesUsage.data.ciMinutesProjectMonthlyUsage.nodes),
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(MinutesUsagePerProject, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findNoMinutesAlert = () => wrapper.findComponent(NoMinutesAlert);
  const findMinutesByProject = () => wrapper.findByTestId('minutes-by-project');
  const findSharedRunnerByProject = () => wrapper.findByTestId('shared-runner-by-project');

  it('does not render NoMinutesAlert if there are compute minutes', () => {
    expect(findNoMinutesAlert().exists()).toBe(false);
  });

  describe('with no compute minutes', () => {
    beforeEach(() => {
      const props = {
        projects: defaultProps.projects.map((project) => ({
          ...project,
          minutes: 0,
        })),
      };

      createComponent({ props });
    });

    it('does not render compute charts', () => {
      expect(findMinutesByProject().exists()).toBe(false);
    });

    it('renders Shared Runners charts', () => {
      expect(findSharedRunnerByProject().exists()).toBe(true);
    });
  });

  describe('with no shared runners', () => {
    beforeEach(() => {
      const props = {
        projects: defaultProps.projects.map((project) => ({
          ...project,
          sharedRunnersDuration: 0,
        })),
      };

      createComponent({ props });
    });

    it('renders compute charts', () => {
      expect(findMinutesByProject().exists()).toBe(true);
    });

    it('does not render Shared Runners charts', () => {
      expect(findSharedRunnerByProject().exists()).toBe(false);
    });
  });
});
