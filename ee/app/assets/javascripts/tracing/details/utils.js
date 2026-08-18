import { createIssueUrlWithDetails } from '~/observability/utils';
import { formatTraceDuration } from '../trace_utils';

export function createIssueUrlWithTraceDetails({ trace, totalErrors, createIssueUrl }) {
  const traceDetails = {
    fullUrl: window.location.href,
    name: `${trace.service_name} : ${trace.operation}`,
    traceId: trace.trace_id,
    start: new Date(trace.timestamp).toUTCString(),
    duration: formatTraceDuration(trace.duration_nano),
    totalSpans: trace.total_spans,
    totalErrors,
  };
  return createIssueUrlWithDetails(createIssueUrl, traceDetails, 'observability_trace_details');
}
