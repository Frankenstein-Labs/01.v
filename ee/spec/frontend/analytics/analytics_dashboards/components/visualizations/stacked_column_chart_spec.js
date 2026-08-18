import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StackedColumnChart from 'ee/analytics/analytics_dashboards/components/visualizations/stacked_column_chart.vue';
import { CHART_TOOLTIP_TITLE_FORMATTERS, UNITS } from '~/analytics/shared/constants';
import { stubComponent } from 'helpers/stub_component';

describe('StackedColumnChart Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockBarsData = [
    {
      name: 'Production',
      data: [4500, 52, 48, 610, 58, 65],
    },
    {
      name: 'Staging',
      data: [7800, 85, 92, 88, 95, 1020],
    },
    {
      name: 'Development',
      data: [1200, 135, 128, 142, 138, 155],
    },
  ];

  const mockGroupBy = ['Jan 2025', 'Feb 2025', 'Mar 2025', 'Apr 2025', 'May 2025', 'Jun 2025'];

  const mockData = { bars: mockBarsData, groupBy: mockGroupBy };

  const mockOptions = {
    yAxis: { name: 'Deploys', type: 'value' },
    xAxis: { name: 'Month', type: 'category' },
    presentation: 'tiled',
  };

  const findStackedColumnChart = () => wrapper.findComponent(GlStackedColumnChart);
  const findChartTooltipTitle = () => wrapper.findByTestId('chart-tooltip-title');
  const findAllChartTooltipItems = () => wrapper.findAllByTestId('chart-tooltip-item');
  const findChartTooltipSeriesLabel = (idx = 0) =>
    wrapper.findAllComponents(GlChartSeriesLabel).at(idx);
  const findChartTooltipValue = (idx = 0) => wrapper.findAllByTestId('chart-tooltip-value').at(idx);

  const createWrapper = ({ data = mockData, options = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(StackedColumnChart, {
      propsData: {
        data,
        options: { ...mockOptions, ...options },
      },
      stubs,
    });
  };

  it('should render the chart with provided data and options', () => {
    createWrapper();

    expect(findStackedColumnChart().props()).toMatchObject({
      bars: mockBarsData,
      groupBy: mockGroupBy,
      option: expect.objectContaining({
        xAxis: expect.objectContaining({
          name: 'Month',
          type: 'category',
          axisPointer: { type: 'shadow' },
        }),
        yAxis: expect.objectContaining({ name: 'Deploys', type: 'value' }),
      }),
      xAxisType: 'category',
      xAxisTitle: 'Month',
      yAxisTitle: 'Deploys',
      height: 'auto',
      presentation: 'tiled',
      includeLegendAvgMax: false,
    });

    expect(findStackedColumnChart().attributes('responsive')).toBe('');
  });

  it(`can toggle the legend's average / max values`, () => {
    createWrapper({ options: { includeLegendAvgMax: true } });

    expect(findStackedColumnChart().props().includeLegendAvgMax).toBe(true);
  });

  it('does not pass `tooltip` option to chart options', () => {
    createWrapper({ options: { tooltip: { description: 'Panel tooltip' } } });

    expect(findStackedColumnChart().props().option).not.toHaveProperty('tooltip');
  });

  describe('tooltip', () => {
    const mockParams = {
      value: 'Jan 2025',
      seriesData: [
        {
          name: 'Jan 2025',
          borderColor: 'blue',
          seriesIndex: 0,
          seriesName: 'Production',
          value: 4500,
        },
        {
          name: 'Jan 2025',
          borderColor: 'red',
          seriesIndex: 1,
          seriesName: 'Staging',
          value: 7800,
        },
      ],
    };

    const tooltipConfig = {
      titleFormatter: CHART_TOOLTIP_TITLE_FORMATTERS.VALUE_ONLY,
      valueUnit: UNITS.COUNT,
    };

    const createTooltipStub = (params = mockParams) => ({
      GlStackedColumnChart: stubComponent(GlStackedColumnChart, {
        data() {
          return { params };
        },
        template: `
          <div>
            <slot name="tooltip-title" :params="params"></slot>
            <slot name="tooltip-content" :params="params"></slot>
          </div>
        `,
      }),
    });

    it('formats the tooltip correctly when no options have been defined', () => {
      createWrapper({
        options: {
          chartTooltip: undefined,
        },
        stubs: createTooltipStub(),
      });

      expect(findChartTooltipTitle().text()).toBe('Jan 2025 (Month)');

      expect(findAllChartTooltipItems()).toHaveLength(2);

      expect(findChartTooltipSeriesLabel(0).text()).toBe('Production');
      expect(findChartTooltipSeriesLabel(0).props().color).toBe('blue');
      expect(findChartTooltipValue(0).text()).toBe('4500');

      expect(findChartTooltipSeriesLabel(1).text()).toBe('Staging');
      expect(findChartTooltipSeriesLabel(1).props().color).toBe('red');
      expect(findChartTooltipValue(1).text()).toBe('7800');
    });

    it('formats the tooltip correctly when options have been defined', () => {
      createWrapper({
        options: {
          chartTooltip: tooltipConfig,
        },
        stubs: createTooltipStub(),
      });

      expect(findAllChartTooltipItems()).toHaveLength(2);

      expect(findChartTooltipSeriesLabel(0).text()).toBe('Production');
      expect(findChartTooltipSeriesLabel(0).props().color).toBe('blue');
      expect(findChartTooltipValue(0).text()).toBe('4,500');

      expect(findChartTooltipSeriesLabel(1).text()).toBe('Staging');
      expect(findChartTooltipSeriesLabel(1).props().color).toBe('red');
      expect(findChartTooltipValue(1).text()).toBe('7,800');
    });

    it('inverts order of tooltip items when columns are stacked', () => {
      createWrapper({
        options: {
          chartTooltip: tooltipConfig,
          presentation: 'stacked',
        },
        stubs: createTooltipStub(),
      });

      expect(findAllChartTooltipItems()).toHaveLength(2);

      expect(findChartTooltipSeriesLabel(0).text()).toBe('Staging');
      expect(findChartTooltipSeriesLabel(0).props().color).toBe('red');
      expect(findChartTooltipValue(0).text()).toBe('7,800');

      expect(findChartTooltipSeriesLabel(1).text()).toBe('Production');
      expect(findChartTooltipSeriesLabel(1).props().color).toBe('blue');
      expect(findChartTooltipValue(1).text()).toBe('4,500');
    });
  });
});
