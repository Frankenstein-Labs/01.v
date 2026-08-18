import { GlLink, GlLoadingIcon, GlSkeletonLoader, GlEmptyState } from '@gitlab/ui';
import { GlSingleStat, GlLineChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import { stubComponent } from 'helpers/stub_component';

import RunnerWaitTimes from 'ee/ci/runner/components/runner_wait_times.vue';
import { I18N_MEDIAN, I18N_P75, I18N_P90, I18N_P99 } from 'ee/ci/runner/constants';

import HelpPopover from '~/vue_shared/components/help_popover.vue';

import { queuedDuration as waitTimes, timeSeries as waitTimeHistory } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

const waitTimesPopoverDescription = 'Popover description';
const waitTimeHistoryEmptyStateDescription = 'Empty state description';

describe('RunnerActiveList', () => {
  let wrapper;

  const findSingleStats = () => wrapper.findAllComponents(GlSingleStat);
  const findHelpPopover = () => wrapper.findComponent(HelpPopover);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findChart = () => wrapper.findComponent(GlLineChart);

  const getStatData = () =>
    findSingleStats().wrappers.map((w) => [w.props('title'), w.props('value')]);

  const createComponent = ({ props, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerWaitTimes, {
      propsData: {
        waitTimesPopoverDescription,
        waitTimeHistoryEmptyStateDescription,
        waitTimeHistoryEnabled: true,
        ...props,
      },
      ...options,
    });
  };

  describe('When loading data', () => {
    useFakeDate('2023-9-18');

    beforeEach(() => {
      createComponent({
        props: {
          waitTimesLoading: true,
          waitTimeHistoryLoading: true,
        },
      });
    });

    it('shows loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('shows loading area', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('shows help popover with link', () => {
      expect(findHelpPopover().text()).toContain(waitTimesPopoverDescription);
      expect(findHelpPopover().findComponent(GlLink).exists()).toBe(true);
    });

    it('shows placeholder stats', () => {
      expect(getStatData()).toEqual([
        [I18N_MEDIAN, '-'],
        [I18N_P75, '-'],
        [I18N_P90, '-'],
        [I18N_P99, '-'],
      ]);
    });

    it('shows no chart', () => {
      expect(findChart().exists()).toBe(false);
    });
  });

  describe('When wait times are loaded', () => {
    beforeEach(() => {
      createComponent({
        props: {
          waitTimes,
          waitTimeHistory,
          waitTimesLoading: false,
          waitTimeHistoryLoading: false,
        },
      });
    });

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows stats', () => {
      expect(getStatData()).toEqual([
        [I18N_P99, '99.00'],
        [I18N_P90, '90.00'],
        [I18N_P75, '75.00'],
        [I18N_MEDIAN, '50.00'],
      ]);
    });

    it('shows chart', () => {
      const chartData = findChart().props('data');

      expect(chartData).toHaveLength(4); // p99, p95, p90 & p50

      chartData.forEach(({ name, data }) => {
        expect(name).toEqual(expect.any(String));
        expect(data).toHaveLength(2); // 2 sample points
      });
    });

    it('shows chart formatted tooltip', () => {
      createComponent({
        props: {
          waitTimeHistory,
        },
        stubs: {
          GlLineChart: stubComponent(GlLineChart, {
            template: `<div>
                        <slot name="tooltip-value" :value="1234.567"></slot>
                      </div>`,
          }),
        },
      });

      expect(findChart().text()).toContain('1,234.57');
    });
  });

  describe('When wait times are empty', () => {
    beforeEach(() => {
      createComponent({
        props: { waitTimeHistory: [] },
      });
    });

    it('shows an empty state', () => {
      expect(findGlEmptyState().props('description')).toContain(
        waitTimeHistoryEmptyStateDescription,
      );
    });
  });

  describe('When ClickHouse is not configured', () => {
    beforeEach(() => {
      createComponent({
        props: {
          waitTimes,
          waitTimeHistory,
          waitTimeHistoryEnabled: false,
        },
      });
    });

    it('does not show the chart', () => {
      expect(findChart().exists()).toBe(false);
    });
  });
});
