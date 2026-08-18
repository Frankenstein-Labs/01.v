import { assignColorToServices } from 'ee/tracing/trace_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingChart from 'ee/tracing/details/tracing_chart.vue';
import TracingDetailsSpansChart from 'ee/tracing/details/tracing_spans_chart.vue';
import { createMockTrace } from '../mock_data';

jest.mock('ee/tracing/trace_utils');

describe('TracingChart', () => {
  let wrapper;

  const mockTrace = createMockTrace(2);

  const mountComponent = () => {
    wrapper = shallowMountExtended(TracingChart, {
      propsData: {
        trace: mockTrace,
        selectedSpanId: mockTrace.spans[0].span_id,
        spanTrees: [mockTrace.spans[0], mockTrace.spans[1]],
      },
    });
  };

  beforeEach(() => {
    assignColorToServices.mockReturnValue({ tracegen: 'red' });

    mountComponent();
  });

  const getTracingDetailsSpansCharts = () => wrapper.findAllComponents(TracingDetailsSpansChart);

  it('renders a TracingDetailsSpansChart for each root', () => {
    const charts = getTracingDetailsSpansCharts();
    expect(charts).toHaveLength(2);
    expect(charts.at(0).props('spans')).toEqual([mockTrace.spans[0]]);
    expect(charts.at(1).props('spans')).toEqual([mockTrace.spans[1]]);
  });

  it('passes the correct props to the TracingDetailsSpansChart component', () => {
    const tracingDetailsSpansChart = getTracingDetailsSpansCharts().at(0);

    expect(tracingDetailsSpansChart.props('traceDurationMs')).toBe(1000);
    expect(tracingDetailsSpansChart.props('serviceToColor')).toEqual({ tracegen: 'red' });
    expect(tracingDetailsSpansChart.props('selectedSpanId')).toEqual(mockTrace.spans[0].span_id);
  });

  it('emits span-selected upon span selection', () => {
    getTracingDetailsSpansCharts()
      .at(0)
      .vm.$emit('span-selected', { spanId: mockTrace.spans[0].span_id });

    expect(wrapper.emitted('span-selected')).toStrictEqual([
      [{ spanId: mockTrace.spans[0].span_id }],
    ]);
  });
});
