import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { nextTick } from 'vue';
import MetricsLineChart from 'ee/metrics/details/metrics_line_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MetricsLineChart', () => {
  const mockData = [
    {
      name: 'container_cpu_usage_seconds_total',
      type: 'Gauge',
      unit: 's',
      attributes: { foo: 'bar', baz: 'abc' },
      values: [
        [`${1700118610000 * 1e6}`, '0.25595267476015443', ['trace-1', 'trace-2']],
        [`${1700118660000 * 1e6}`, '0.1881374588830907', null],
        [`${1700118720000 * 1e6}`, '0.28915416028993485', []],
      ],
    },
    {
      name: 'container_cpu_usage_seconds_total',
      type: 'Gauge',
      unit: 's',
      attributes: { foo: 'bar', baz: 'def' },
      values: [
        [`${1700118610000 * 1e6}`, '1.2658100987444416', []],
        [`${1700118660000 * 1e6}`, '3.0604918827864345', []],
        [`${1700118720000 * 1e6}`, '3.0205790879854124', []],
      ],
    },
  ];

  let wrapper;

  const mountComponent = ({
    data = mockData,
    loading = false,
    cancelled = false,
    chartInteractive = true,
  } = {}) => {
    wrapper = shallowMountExtended(MetricsLineChart, {
      propsData: {
        metricData: data,
        loading,
        cancelled,
        chartInteractive,
      },
    });
  };

  const findChart = () => wrapper.findComponent(GlLineChart);

  const getSymbolSizeFn = () => findChart().props('data')[0].symbolSize;
  const mockSymbolSize = (datapoint) =>
    parseFloat(getSymbolSizeFn()(null, { data: datapoint }).toFixed(2));

  const getDatapoint = (seriesIndex, datapointIndex) =>
    findChart().props('data')[seriesIndex].data[datapointIndex];

  const datapointWithTracingData = () => getDatapoint(0, 0);
  const datapointWithNoTracingData = () => getDatapoint(1, 0);

  const chartItemClicked = ({ series = [], timestamp, activeSeriesIndexes }) =>
    findChart().vm.$emit('chartItemClicked', {
      chart: {
        getModel: () => ({
          getSeries: () => series,
          getCurrentSeriesIndices: () => activeSeriesIndexes ?? series.map((_, i) => i),
        }),
      },
      params: { data: [timestamp] },
    });

  beforeEach(() => {
    mountComponent();
  });

  it('renders GlChart component', () => {
    expect(findChart().exists()).toBe(true);
  });

  describe('chart data', () => {
    it('passes chart data to GlLineChart via props', () => {
      expect(findChart().props('data')).toEqual([
        {
          data: [
            [
              mockData[0].values[0][0] / 1e6,
              parseFloat(mockData[0].values[0][1]),
              { ...mockData[0].attributes },
              { traceIds: mockData[0].values[0][2] },
            ],
            [
              mockData[0].values[1][0] / 1e6,
              parseFloat(mockData[0].values[1][1]),
              { ...mockData[0].attributes },
              { traceIds: [] },
            ],
            [
              mockData[0].values[2][0] / 1e6,
              parseFloat(mockData[0].values[2][1]),
              { ...mockData[0].attributes },
              { traceIds: mockData[0].values[2][2] },
            ],
          ],
          name: 'foo: bar, baz: abc',
          symbolSize: expect.any(Function),
          symbol: expect.any(Function),
        },
        {
          data: [
            [
              mockData[1].values[0][0] / 1e6,
              parseFloat(mockData[1].values[0][1]),
              { ...mockData[1].attributes },
              { traceIds: mockData[1].values[0][2] },
            ],
            [
              mockData[1].values[1][0] / 1e6,
              parseFloat(mockData[1].values[1][1]),
              { ...mockData[1].attributes },
              { traceIds: mockData[1].values[1][2] },
            ],
            [
              mockData[1].values[2][0] / 1e6,
              parseFloat(mockData[1].values[2][1]),
              { ...mockData[1].attributes },
              { traceIds: mockData[1].values[2][2] },
            ],
          ],
          name: 'foo: bar, baz: def',
          symbolSize: expect.any(Function),
          symbol: expect.any(Function),
        },
      ]);
    });

    it('sets the symbol size based on whether tracing data is available', () => {
      expect(mockSymbolSize(datapointWithTracingData())).toBe(12);
      expect(mockSymbolSize(datapointWithNoTracingData())).toBe(6);
    });
  });

  describe('chart options', () => {
    it('adds the unit to the y axis label if available in the data', () => {
      expect(findChart().props('option').yAxis.name).toBe('Value (s)');
    });

    it('does not add any unit to the y axis label if not in the data', () => {
      const data = [{ ...mockData[0], unit: '' }];
      mountComponent({ data });
      expect(findChart().props('option').yAxis.name).toBe('Value');
    });
  });

  describe('chartItemClicked', () => {
    const mockSeries = (color, name, data) => ({
      option: { data, itemStyle: { color } },
      name,
    });

    it('emits selected event with the correct params', async () => {
      await chartItemClicked({
        series: [
          mockSeries('color-1', 'series-1', [
            [1234, 'val-1', {}, { traceIds: ['trace-1'] }],
            [5678, 'val-2', {}, { traceIds: ['trace-2'] }],
          ]),
          mockSeries('color-0', 'series-0', [
            [1234, 'val-3', {}, { traceIds: ['trace-3'] }],
            [5678, 'val-4', {}, { traceIds: ['trace-4'] }],
          ]),
        ],
        timestamp: 1234,
      });
      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([
        [
          {
            color: 'color-1',
            seriesName: 'series-1',
            timestamp: 1234,
            traceIds: ['trace-1'],
            value: 'val-1',
          },
          {
            color: 'color-0',
            seriesName: 'series-0',
            timestamp: 1234,
            traceIds: ['trace-3'],
            value: 'val-3',
          },
        ],
      ]);
    });

    it('does not return data points from time series that are not active', async () => {
      await chartItemClicked({
        series: [
          mockSeries('color-1', 'series-1', [[1234, 'val-1', {}, { traceIds: ['trace-1'] }]]),
          mockSeries('color-0', 'series-0', [[1234, 'val-3', {}, { traceIds: ['trace-3'] }]]),
        ],
        timestamp: 1234,
        activeSeriesIndexes: [0],
      });
      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([
        [
          {
            color: 'color-1',
            seriesName: 'series-1',
            timestamp: 1234,
            traceIds: ['trace-1'],
            value: 'val-1',
          },
        ],
      ]);
    });

    it('sets annotation based on the selected timestamp', async () => {
      expect(findChart().props('annotations')).toEqual([]);

      await chartItemClicked({
        series: [
          mockSeries('color-1', 'series-1', [
            [new Date('2024-09-01').getTime(), 'val-1', {}, { traceIds: ['trace-1'] }],
            [5678, 'val-2', {}, { traceIds: ['trace-2'] }],
          ]),
          mockSeries('color-0', 'series-0', [
            [new Date('2024-09-01').getTime(), 'val-3', {}, { traceIds: ['trace-3'] }],
            [5678, 'val-4', {}, { traceIds: ['trace-4'] }],
          ]),
        ],
        timestamp: new Date('2024-09-01').getTime(),
      });

      expect(findChart().props('annotations')).toEqual([
        { min: new Date('2024-09-01'), max: new Date('2024-09-01') },
      ]);
    });

    it('ignores clicks on the annotations', () => {
      findChart().vm.$emit('chartItemClicked', {
        chart: {},
        params: { data: { name: 'annotations' } },
      });
      expect(wrapper.emitted('selected')).toBeUndefined();
    });

    it('does not emit selected events if the chart is not interactive', async () => {
      mountComponent({ chartInteractive: false });

      await chartItemClicked({
        series: [
          mockSeries('color-1', 'series-1', [
            [1234, 'val-1', {}, { traceIds: ['trace-1'] }],
            [5678, 'val-2', {}, { traceIds: ['trace-2'] }],
          ]),
        ],
        timestamp: 1234,
      });
      expect(wrapper.emitted('selected')).toBeUndefined();
    });
  });

  describe('tooltip', () => {
    const mockTooltipData = [
      {
        data: [
          mockData[0].values[0][0] / 1e6,
          mockData[0].values[0][1],
          { ...mockData[0].attributes },
        ],
        name: 'series-0',
        color: 'color-0',
        seriesId: 'id-0',
      },
      {
        data: [
          mockData[1].values[0][0] / 1e6,
          mockData[1].values[0][1],
          { ...mockData[1].attributes },
        ],
        name: 'series-1',
        color: 'color-1',
        seriesId: 'id-1',
      },
    ];

    const mockFormatTooltipText = async (data = []) => {
      findChart().props('formatTooltipText')({ seriesData: data });
      await nextTick();
    };

    const getTooltipTitle = () => findChart().find(`[data-testid="metric-tooltip-title"]`);

    beforeEach(async () => {
      await mockFormatTooltipText(mockTooltipData);
    });

    describe('title', () => {
      it('sets the title to the x data point of the first series', () => {
        expect(getTooltipTitle().text()).toBe('Nov 16 2023 07:10:10 UTC');
      });

      it('handles empty data', async () => {
        await mockFormatTooltipText();

        expect(getTooltipTitle().text()).toBe('');
      });
    });

    describe('content', () => {
      const expectedLabels = [
        ['foo: bar', 'baz: abc'],
        ['foo: bar', 'baz: def'],
      ];

      it('renders content for each time series', () => {
        const content = findChart().findAll(`[data-testid="metric-tooltip-content"]`);
        expect(content).toHaveLength(mockTooltipData.length);
        content.wrappers.forEach((w, i) => {
          const timeseries = mockTooltipData[i];

          expect(w.find(`[data-testid="metric-tooltip-value"]`).text()).toBe(
            parseFloat(timeseries.data[1]).toFixed(3),
          );

          const label = w.findComponent(GlChartSeriesLabel);
          expect(label.props('color')).toBe(timeseries.color);

          const attributeContainers = label.findAll('div');
          expect(attributeContainers).toHaveLength(Object.entries(timeseries.data[2]).length);
          attributeContainers.wrappers.forEach((c, j) => {
            expect(c.text()).toBe(expectedLabels[i][j]);
          });
        });
      });
    });
  });
  describe('loading', () => {
    it('changes the opacity when loading', () => {
      mountComponent({ loading: true });

      expect(findChart().classes()).toContain('gl-opacity-3');
    });

    it('does not change the opacity when not loading', () => {
      mountComponent({ loading: false });

      expect(findChart().classes()).not.toContain('gl-opacity-3');
    });
  });

  describe('cancelled', () => {
    const cancelledText = 'Metrics search has been cancelled.';

    describe('when cancelled=true', () => {
      beforeEach(() => {
        mountComponent({ cancelled: true });
      });

      it('overrides the opacity', () => {
        expect(findChart().classes()).toContain('gl-opacity-3');
      });

      it('shows the cancelled messaged', () => {
        expect(wrapper.text()).toContain(cancelledText);
      });
    });

    describe('when cancelled=false', () => {
      beforeEach(() => {
        mountComponent({ cancelled: false });
      });

      it('overrides the opacity', () => {
        expect(findChart().classes()).not.toContain('gl-opacity-3');
      });

      it('shows the cancelled messaged', () => {
        expect(wrapper.text()).not.toContain(cancelledText);
      });
    });
  });
});
