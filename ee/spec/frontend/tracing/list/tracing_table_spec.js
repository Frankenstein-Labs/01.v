import { nextTick } from 'vue';
import { GlTable } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TracingTable from 'ee/tracing/list/tracing_table.vue';

describe('TracingTable', () => {
  let wrapper;
  const mockTraces = [
    {
      timestamp: '2023-07-10T15:02:30.677538Z',
      service_name: 'tracegen',
      operation: 'lets-go',
      duration_nano: 1500000,
      trace_id: 'trace-1',
      total_spans: 1,
      matched_span_count: 1,
    },
    {
      timestamp: '2023-08-11T16:03:40.577538Z',
      service_name: 'tracegen-2',
      operation: 'lets-go-2',
      duration_nano: 2000000,
      trace_id: 'trace-2',
      total_spans: 3,
      matched_span_count: 2,
      error_span_count: 1,
    },
    {
      timestamp: '2023-08-11T16:03:50.577538Z',
      service_name: 'tracegen-3',
      operation: 'lets-go-3',
      duration_nano: 2000000,
      trace_id: 'trace-3',
      total_spans: 3,
      matched_span_count: 2,
      error_span_count: 1,
      in_progress: true,
    },
  ];

  const expectedTraces = [
    {
      timestamp: 'Jul 10 2023 15:02:30.677 UTC',
      badge: '1 span',
      errorBadge: undefined,
      service_name: 'tracegen',
      operation: 'lets-go',
      duration: '1.50ms',
      trace_id: 'trace-1',
    },
    {
      timestamp: 'Aug 11 2023 16:03:40.577 UTC',
      badge: '3 spans / 2 matches',
      errorBadge: '1 error',
      service_name: 'tracegen-2',
      operation: 'lets-go-2',
      duration: '2ms',
      trace_id: 'trace-2',
    },
    {
      timestamp: 'Aug 11 2023 16:03:50.577 UTC',
      badge: '3 spans',
      errorBadge: '1 error',
      service_name: 'tracegen-3',
      operation: 'lets-go-3',
      duration: '2ms',
      trace_id: 'trace-3',
      inProgressBadge: true,
    },
  ];

  const mountComponent = ({ traces = mockTraces, highlightedTraceId } = {}) => {
    wrapper = mountExtended(TracingTable, {
      propsData: {
        traces,
        highlightedTraceId,
      },
    });
  };

  const getRows = () => wrapper.findComponent(GlTable).findAll(`[data-testid="trace-row"]`);
  const getRow = (idx) => getRows().at(idx);

  const clickRow = async (idx) => {
    getRow(idx).trigger('click');
    await nextTick();
  };

  it('renders traces as table', () => {
    mountComponent();

    const rows = getRows();
    expect(rows).toHaveLength(mockTraces.length);
    mockTraces.forEach((_, i) => {
      const row = getRows().at(i);
      const expected = expectedTraces[i];
      expect(row.find(`[data-testid="trace-timestamp"]`).text()).toContain(expected.timestamp);
      expect(row.find(`[data-testid="trace-service"]`).text()).toBe(expected.service_name);
      expect(row.find(`[data-testid="trace-operation"]`).text()).toBe(expected.operation);
      expect(row.find(`[data-testid="trace-duration"]`).text()).toBe(expected.duration);
      expect(row.find(`[data-testid="trace-timestamp"]`).text()).toContain(expected.badge);

      if (expected.errorBadge) {
        expect(row.find(`[data-testid="trace-timestamp"]`).text()).toContain(expected.errorBadge);
      } else {
        expect(row.find(`[data-testid="trace-timestamp"]`).text()).not.toContain('error');
      }

      if (expected.inProgressBadge) {
        expect(row.find(`[data-testid="trace-timestamp"]`).text()).toContain('In progress');
      } else {
        expect(row.find(`[data-testid="trace-timestamp"]`).text()).not.toContain('In progress');
      }
    });
  });

  it('emits trace-clicked on row-clicked', async () => {
    mountComponent();

    await clickRow(0);
    expect(wrapper.emitted('trace-clicked')[0]).toEqual([
      { traceId: mockTraces[0].trace_id, clickEvent: expect.any(MouseEvent) },
    ]);
  });

  it('sets the correct variant when a trace is highlighted', () => {
    mountComponent({ highlightedTraceId: 'trace-2' });

    expect(getRow(1).classes()).toContain('gl-bg-alpha-dark-8');
    expect(getRow(0).classes()).not.toContain('gl-bg-alpha-dark-8');
  });
});
