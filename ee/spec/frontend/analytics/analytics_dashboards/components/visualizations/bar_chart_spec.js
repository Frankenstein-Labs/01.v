import { GlBarChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import BarChart from 'ee/analytics/analytics_dashboards/components/visualizations/bar_chart.vue';
import { CHART_TOOLTIP_TITLE_FORMATTERS, UNITS } from '~/analytics/shared/constants';

describe('BarChart Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockData = {
    Pushes: [
      [100, 'jim'],
      [210, 'dwight'],
      [300, 'pam'],
    ],
  };

  const mockDataWithContext = {
    ...mockData,
    contextualData: {
      jim: { repositories: 5, contributions: 23 },
      dwight: { repositories: 8, contributions: 1000 },
      pam: { repositories: 12, contributions: 67 },
    },
  };

  const mockOptions = {
    yAxis: { name: 'User' },
    xAxis: { name: 'Stars', type: 'value' },
    presentation: 'tiled',
  };

  const findBarChart = () => wrapper.findComponent(GlBarChart);
  const findChartTooltipTitle = () => wrapper.findByTestId('chart-tooltip-title');
  const findAllChartTooltipItems = () => wrapper.findAllByTestId('chart-tooltip-item');
  const findChartTooltipSeriesLabel = (idx = 0) =>
    wrapper.findAllComponents(GlChartSeriesLabel).at(idx);
  const findChartTooltipValue = (idx = 0) => wrapper.findAllByTestId('chart-tooltip-value').at(idx);

  const createWrapper = ({ data = mockData, options = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(BarChart, {
      propsData: { data, options: { ...mockOptions, ...options } },
      stubs,
    });
  };

  describe('when mounted', () => {
    it('should render the bar chart with provided data and options', () => {
      createWrapper();

      expect(findBarChart().props()).toMatchObject({
        data: expect.objectContaining({
          Pushes: [
            [100, 'jim'],
            [210, 'dwight'],
            [300, 'pam'],
          ],
        }),
        option: expect.objectContaining({
          yAxis: { name: 'User' },
          xAxis: { name: 'Stars', type: 'value' },
        }),
        xAxisType: 'value',
        xAxisTitle: 'Stars',
        yAxisTitle: 'User',
        height: 'auto',
        presentation: 'tiled',
      });

      expect(findBarChart().attributes('responsive')).toBe('');
    });

    it('does not pass `tooltip` option to chart options', () => {
      createWrapper({ options: { tooltip: { description: 'Panel tooltip' } } });

      expect(findBarChart().props().option).not.toHaveProperty('tooltip');
    });

    describe('with contextual data', () => {
      beforeEach(() => {
        createWrapper({ data: mockDataWithContext });
      });

      it('only passes primary data to chart', () => {
        expect(findBarChart().props().data).toEqual(mockData);
      });
    });

    describe('with no data', () => {
      beforeEach(() => {
        createWrapper({ data: {} });
      });

      it('passes empty object to chart', () => {
        expect(findBarChart().props().data).toEqual({});
      });
    });
  });

  describe('tooltip', () => {
    const mockSeries = {
      seriesIndex: 0,
      seriesId: 'pushes',
      seriesName: 'Pushes',
      value: [3000, 'dwight'],
      color: 'blue',
    };

    const tooltipConfig = {
      titleFormatter: CHART_TOOLTIP_TITLE_FORMATTERS.TITLE_CASE,
      valueUnit: UNITS.COUNT,
    };

    const contextualDataConfig = [
      { key: 'repositories', label: 'Repositories' },
      { key: 'contributions', label: 'Contributions', unit: UNITS.COUNT },
    ];

    const createTooltipStub = (seriesData = [mockSeries]) => ({
      GlBarChart: stubComponent(GlBarChart, {
        data() {
          const [, title] = seriesData[0].value;
          return { title, params: { seriesData } };
        },
        template: `
          <div>
            <slot name="tooltip-title" :title="title" :params="params"></slot>
            <slot name="tooltip-content" :params="params"></slot>
          </div>
        `,
      }),
    });

    it.each`
      description                       | tooltipOptions   | expectedTitle | expectedValue
      ${'no options have been defined'} | ${undefined}     | ${'dwight'}   | ${'3000'}
      ${'options have been defined'}    | ${tooltipConfig} | ${'Dwight'}   | ${'3,000'}
    `(
      'formats the tooltip correctly when $description',
      ({ tooltipOptions, expectedTitle, expectedValue }) => {
        createWrapper({
          options: {
            chartTooltip: tooltipOptions,
          },
          stubs: createTooltipStub(),
        });

        expect(findChartTooltipTitle().text()).toBe(expectedTitle);

        expect(findAllChartTooltipItems()).toHaveLength(1);

        expect(findChartTooltipSeriesLabel().text()).toBe('Pushes');
        expect(findChartTooltipValue().text()).toBe(expectedValue);
        expect(findChartTooltipValue().classes()).toContain('gl-font-bold');
      },
    );

    describe('with contextual data', () => {
      it('formats tooltip correctly with contextual data', () => {
        createWrapper({
          data: mockDataWithContext,
          options: {
            chartTooltip: {
              ...tooltipConfig,
              contextualData: contextualDataConfig,
            },
          },
          stubs: createTooltipStub(),
        });

        expect(findChartTooltipTitle().text()).toBe('Dwight');

        expect(findAllChartTooltipItems()).toHaveLength(3);

        expect(findChartTooltipSeriesLabel(0).text()).toBe('Pushes');
        expect(findChartTooltipSeriesLabel(0).props().color).toBe('blue');
        expect(findChartTooltipValue(0).text()).toBe('3,000');
        expect(findChartTooltipValue(0).classes()).toContain('gl-font-bold');

        expect(findChartTooltipSeriesLabel(1).text()).toBe('Repositories');
        expect(findChartTooltipSeriesLabel(1).props().color).toBe('transparent');
        expect(findChartTooltipValue(1).text()).toBe('8');
        expect(findChartTooltipValue(1).classes()).toContain('gl-font-normal');

        expect(findChartTooltipSeriesLabel(2).text()).toBe('Contributions');
        expect(findChartTooltipSeriesLabel(2).props().color).toBe('transparent');
        expect(findChartTooltipValue(2).text()).toBe('1,000');
        expect(findChartTooltipValue(2).classes()).toContain('gl-font-normal');
      });

      it('does not display contextual data when contextual data config is missing', () => {
        createWrapper({
          data: mockDataWithContext,
          stubs: createTooltipStub(),
        });

        expect(findChartTooltipTitle().text()).toBe('dwight');

        expect(findAllChartTooltipItems()).toHaveLength(1);

        expect(findChartTooltipSeriesLabel().text()).toBe('Pushes');
        expect(findChartTooltipValue().text()).toBe('3000');
      });

      it('does not display contextual data when data is missing', () => {
        createWrapper({
          options: {
            chartTooltip: {
              contextualData: contextualDataConfig,
            },
          },
          stubs: createTooltipStub(),
        });

        expect(findChartTooltipTitle().text()).toBe('dwight');

        expect(findAllChartTooltipItems()).toHaveLength(1);

        expect(findChartTooltipSeriesLabel().text()).toBe('Pushes');
        expect(findChartTooltipValue().text()).toBe('3000');
      });

      it('does not display contextual data with unknown key from contextual data config', () => {
        createWrapper({
          data: mockDataWithContext,
          options: {
            chartTooltip: {
              contextualData: [
                { key: 'contributions', label: 'Contributions' },
                { key: 'unknown', label: 'Repositories' },
              ],
            },
          },
          stubs: createTooltipStub(),
        });

        expect(findChartTooltipTitle().text()).toBe('dwight');

        expect(findAllChartTooltipItems()).toHaveLength(2);

        expect(findChartTooltipSeriesLabel(0).text()).toBe('Pushes');
        expect(findChartTooltipValue(0).text()).toBe('3000');

        expect(findChartTooltipSeriesLabel(1).text()).toBe('Contributions');
        expect(findChartTooltipValue(1).text()).toBe('1000');
      });
    });
  });
});
