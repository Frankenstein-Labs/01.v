import { times } from 'lodash-es';

export const createMockTrace = (
  spansNumber = 10,
  {
    traceDurationNano = 1000000000,
    traceId = '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8',
    serviceName = 'Service',
    operation = 'Operation',
    timestamp = 1692021937219,
  } = {},
) => {
  const trace = {
    duration_nano: traceDurationNano,
    spans: [],
    total_spans: spansNumber,
    operation,
    service_name: serviceName,
    trace_id: traceId,
    timestamp,
    statusCode: 'STATUS_CODE_UNSET',
  };

  trace.spans = times(spansNumber).map((i) => ({
    timestamp: new Date().toISOString(),
    span_id: `SPAN-${i}`,
    trace_id: 'fake-trace',
    service_name: `service-${i}`,
    operation: 'op',
    duration_nano: 100000,
    parent_span_id: i === 0 ? '' : 'SPAN-0',
  }));
  return trace;
};
