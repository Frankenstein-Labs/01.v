import { shallowMount } from '@vue/test-utils';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { GlIcon } from '@gitlab/ui';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import NoDataAvailableState from 'ee/analytics/cycle_analytics/components/no_data_available_state.vue';
import {
  DURATION_TOTAL_TIME_DESCRIPTION,
  DURATION_OVERVIEW_CHART_NO_DATA_LEGEND_ITEM,
} from 'ee/analytics/cycle_analytics/constants';
import {
  durationOverviewChartPlottableData as mockOverviewChartPlottableData,
  durationOverviewDataSeries,
  durationOverviewDataNullSeries,
  durationOverviewChartOptionsData,
  durationOverviewLegendSeriesInfo,
} from '../../mock_data';

describe('OverviewChart', () => {
  let wrapper;
  let mockEChartInstance;

  const findChartDescription = () => wrapper.findComponent(GlIcon);
  const findOverviewChart = () => wrapper.findComponent(GlAreaChart);
  const findNoDataAvailableState = (_wrapper) => _wrapper.findComponent(NoDataAvailableState);

  const emitChartCreated = () => findOverviewChart().vm.$emit('created', mockEChartInstance);

  const mockChartOptionSeries = [...durationOverviewDataSeries, ...durationOverviewDataNullSeries];

  const createComponent = (props = {}) => {
    mockEChartInstance = {
      on: jest.fn(),
      off: jest.fn(),
      getOption: () => {
        return {
          series: mockChartOptionSeries,
        };
      },
    };

    wrapper = shallowMount(OverviewChart, {
      propsData: {
        plottableData: mockOverviewChartPlottableData,
        ...props,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
      emitChartCreated();
    });

    it('renders the chart', () => {
      expect(findOverviewChart().exists()).toBe(true);
    });

    it('renders the chart description', () => {
      expect(findChartDescription().attributes('title')).toBe(DURATION_TOTAL_TIME_DESCRIPTION);
    });

    it('correctly sets the chart options data property', () => {
      const chartDataProps = findOverviewChart().props('data');

      expect(chartDataProps).toStrictEqual([
        ...durationOverviewChartOptionsData,
        ...durationOverviewDataNullSeries,
      ]);
    });

    it('correctly sets the chart legend-series-info property', () => {
      const chartLegendSeriesInfoProps = findOverviewChart().props('legendSeriesInfo');

      expect(chartLegendSeriesInfoProps).toStrictEqual([
        ...durationOverviewLegendSeriesInfo,
        DURATION_OVERVIEW_CHART_NO_DATA_LEGEND_ITEM,
      ]);

      expect(chartLegendSeriesInfoProps).toHaveLength(mockOverviewChartPlottableData.length + 1);
    });
  });

  describe('with no chart data', () => {
    beforeEach(() => {
      createComponent({
        plottableData: [],
      });
    });

    it('renders the no data available message', () => {
      expect(findNoDataAvailableState(wrapper).exists()).toBe(true);
    });
  });
});
