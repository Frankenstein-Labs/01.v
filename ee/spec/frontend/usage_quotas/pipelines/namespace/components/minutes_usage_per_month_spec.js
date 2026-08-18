import { GlLoadingIcon } from '@gitlab/ui';
import { cloneDeep } from 'lodash-es';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/namespace/components/minutes_usage_per_month.vue';
import NoMinutesAlert from 'ee/usage_quotas/pipelines/namespace/components/no_minutes_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockGetNamespaceCiMinutesUsage } from '../mock_data';

describe('MinutesUsagePerMonth', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const defaultProps = {
    ciMinutesUsage: cloneDeep(mockGetNamespaceCiMinutesUsage.data.ciMinutesUsage.nodes),
    selectedYear: 2022,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(MinutesUsagePerMonth, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findNoMinutesAlert = () => wrapper.findComponent(NoMinutesAlert);
  const findMinutesByNamespace = () => wrapper.findByTestId('minutes-by-namespace');
  const findSharedRunnerByNamespace = () => wrapper.findByTestId('shared-runner-by-namespace');
  const findSharedRunnersLoadingIndicator = () =>
    wrapper.findByTestId('pipelines-shared-runners-chart-loading-indicator');
  const findMinutesLoadingIndicator = () =>
    wrapper.findByTestId('pipelines-minutes-chart-loading-indicator');

  describe('when isLoading prop is true', () => {
    beforeEach(() => {
      createComponent({ props: { isLoading: true } });
    });

    it('renders 2 loading-icon when isLoading is true', () => {
      expect(wrapper.findAllComponents(GlLoadingIcon)).toHaveLength(2);
      expect(findMinutesLoadingIndicator().exists()).toBe(true);
      expect(findSharedRunnersLoadingIndicator().exists()).toBe(true);
    });

    it('does not render NoMinutesAlert if isLoading prop is true', () => {
      expect(findNoMinutesAlert().exists()).toBe(false);
    });
  });

  describe('with compute minutes', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render loading-icon', () => {
      expect(wrapper.findAllComponents(GlLoadingIcon)).toHaveLength(0);
    });

    it('does not render NoMinutesAlert if there are compute minutes', () => {
      expect(findNoMinutesAlert().exists()).toBe(false);
    });
  });

  describe('with no compute minutes', () => {
    beforeEach(() => {
      const props = {
        ...defaultProps,
        ciMinutesUsage: defaultProps.ciMinutesUsage.map((usage) => ({
          ...usage,
          minutes: 0,
        })),
      };

      createComponent({ props });
    });

    it('does not render loading-icon', () => {
      expect(wrapper.findAllComponents(GlLoadingIcon)).toHaveLength(0);
    });

    it('does not render compute charts', () => {
      expect(findMinutesByNamespace().exists()).toBe(false);
    });

    it('renders Shared Runners charts', () => {
      expect(findSharedRunnerByNamespace().exists()).toBe(true);
    });
  });

  describe('with no shared runners', () => {
    beforeEach(() => {
      const props = {
        ...defaultProps,
        ciMinutesUsage: defaultProps.ciMinutesUsage.map((usage) => ({
          ...usage,
          sharedRunnersDuration: 0,
        })),
      };

      createComponent({ props });
    });

    it('renders compute charts', () => {
      expect(findMinutesByNamespace().exists()).toBe(true);
    });

    it('does not render Shared Runners charts', () => {
      expect(findSharedRunnerByNamespace().exists()).toBe(false);
    });

    it('renders NoMinutesAlert', () => {
      expect(findNoMinutesAlert().exists()).toBe(true);
    });
  });
});
