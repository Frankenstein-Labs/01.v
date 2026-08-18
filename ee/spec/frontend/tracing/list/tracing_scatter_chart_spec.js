import { GlDiscreteScatterChart } from '@gitlab/ui/src/charts';
import { GL_COLOR_NEUTRAL_200 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingScatterChart from 'ee/tracing/list/tracing_scatter_chart.vue';

describe('TracingScatterChart', () => {
  let wrapper;

  const mockTraces = [
    {
      timestamp: 1620000000,
      duration_nano: 1000000000,
      trace_id: '123',
      status_code: 'STATUS_CODE_ERROR',
    },
    {
      timestamp: 1621000000,
      duration_nano: 2000000000,
      trace_id: '456',
      status_code: 'STATUS_CODE_SUCCESS',
    },
  ];

  const rangeMax = new Date('2023-10-09 15:30:00');
  const rangeMin = new Date('2023-10-09 12:30:00');

  const mountComponent = (traces = mockTraces) => {
    wrapper = shallowMountExtended(TracingScatterChart, {
      propsData: {
        traces,
        height: 300,
        rangeMin,
        rangeMax,
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findChart = () => wrapper.findComponent(GlDiscreteScatterChart);

  it('renders the chart component', () => {
    expect(findChart().exists()).toBe(true);
  });

  it('sets the chart data correctly', () => {
    const expectedChartData = [
      {
        data: [
          { value: [1620000000, 1000], traceId: '123', hasError: true },
          { value: [1621000000, 2000], traceId: '456', hasError: false },
        ],
        type: 'scatter',
        itemStyle: {
          color: expect.any(Function),
        },
        symbol: expect.any(Function),
      },
    ];

    expect(findChart().props('data')).toEqual(expectedChartData);
  });

  it('sets the proper item color', () => {
    expect(
      findChart()
        .props('data')[0]
        .itemStyle.color({ color: 'default', data: { hasError: true } }),
    ).toBe('#ee6666');

    expect(
      findChart()
        .props('data')[0]
        .itemStyle.color({ color: 'default', data: { hasError: false } }),
    ).toBe('default');
  });

  it('sets the proper item symbol', () => {
    expect(
      findChart()
        .props('data')[0]
        .symbol({}, { data: { hasError: true } }),
    ).toBe('triangle');

    expect(
      findChart()
        .props('data')[0]
        .symbol({}, { data: { hasError: false } }),
    ).toBe('circle');
  });

  it('sets the chart option correctly', () => {
    const expectedChartOption = {
      title: undefined,
      dataZoom: [
        {
          type: 'slider',
        },
      ],
      xAxis: {
        type: 'time',
        max: rangeMax,
        min: rangeMin,
        axisLine: {
          show: true,
          lineStyle: {
            color: GL_COLOR_NEUTRAL_200,
          },
        },
      },
    };

    expect(findChart().props('option')).toEqual(expectedChartOption);
  });

  it('sets the proper title when data is missing', () => {
    mountComponent([]);
    expect(findChart().props('option').title).toEqual({
      text: 'No results found',
      subtext: 'Refresh the page, or edit your search filter and try again',
      left: 'center',
      top: '40%',
      textStyle: {
        fontSize: 20,
      },
      subtextStyle: {
        fontSize: 15,
      },
    });
  });

  it('emits the "chart-item-selected" event when a chart item is clicked', () => {
    findChart().vm.$emit('chartItemClicked', { params: { data: { traceId: 'trace-id-test' } } });

    expect(wrapper.emitted('chart-item-selected')).toEqual([[{ traceId: 'trace-id-test' }]]);
  });

  it('emits the "chart-item-over" event when the mouse is over a chart item', () => {
    findChart().vm.$emit('created', {
      on: (funName, fun) => {
        fun({ data: { traceId: 'trace-id-test' } });
      },
    });

    expect(wrapper.emitted('chart-item-over')).toStrictEqual([[{ traceId: 'trace-id-test' }]]);
    expect(wrapper.emitted('chart-item-out')).toStrictEqual([[{ traceId: 'trace-id-test' }]]);
  });
});
