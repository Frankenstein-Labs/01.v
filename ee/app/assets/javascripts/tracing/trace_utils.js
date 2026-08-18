import { s__, sprintf } from '~/locale';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';

// See https://design.gitlab.com/data-visualization/color/#categorical-data
const PALETTE = [
  'gl-bg-data-viz-blue-500',
  'gl-bg-data-viz-orange-500',
  'gl-bg-data-viz-aqua-500',
  'gl-bg-data-viz-green-500',
  'gl-bg-data-viz-magenta-500',
  'gl-bg-data-viz-blue-600',
  'gl-bg-data-viz-orange-600',
  'gl-bg-data-viz-aqua-600',
  'gl-bg-data-viz-green-600',
  'gl-bg-data-viz-magenta-600',
  'gl-bg-data-viz-blue-700',
  'gl-bg-data-viz-orange-700',
  'gl-bg-data-viz-aqua-700',
  'gl-bg-data-viz-green-700',
  'gl-bg-data-viz-magenta-700',
  'gl-bg-data-viz-blue-800',
  'gl-bg-data-viz-orange-800',
  'gl-bg-data-viz-aqua-800',
  'gl-bg-data-viz-green-800',
  'gl-bg-data-viz-magenta-800',
  'gl-bg-data-viz-blue-900',
  'gl-bg-data-viz-orange-900',
  'gl-bg-data-viz-aqua-900',
  'gl-bg-data-viz-green-900',
  'gl-bg-data-viz-magenta-900',
  'gl-bg-data-viz-blue-950',
  'gl-bg-data-viz-orange-950',
  'gl-bg-data-viz-aqua-950',
  'gl-bg-data-viz-green-950',
  'gl-bg-data-viz-magenta-950',
];

export function formatDurationMs(durationMs) {
  if (durationMs <= 0) return s__('Tracing|0ms');

  const durationSecs = durationMs / 1000;
  const milliseconds = durationMs % 1000;
  const seconds = Math.floor(durationSecs) % 60;
  const minutes = Math.floor(durationSecs / 60) % 60;
  const hours = Math.floor(durationSecs / 60 / 60);

  const formattedTime = [];
  if (hours > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{h}h'), { h: hours }));
  }
  if (minutes > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{m}m'), { m: minutes }));
  }
  if (seconds > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{s}s'), { s: seconds }));
  }

  if (milliseconds > 0) {
    const ms =
      durationMs >= 1000 || Math.floor(milliseconds) === milliseconds
        ? Math.floor(milliseconds)
        : milliseconds.toFixed(2);
    formattedTime.push(sprintf(s__('Tracing|%{ms}ms'), { ms }));
  }

  return formattedTime.join(' ');
}

export function formatTraceDuration(durationNano) {
  return formatDurationMs(convertNanoToMs(durationNano));
}

export function assignColorToServices(trace) {
  const services = Array.from(new Set(trace.spans.map((s) => s.service_name)));

  const serviceToColor = {};
  services.forEach((s, i) => {
    serviceToColor[s] = PALETTE[i % PALETTE.length];
  });

  return serviceToColor;
}

const timestampToMs = (ts) => new Date(ts).getTime();

function setNodeStartTs(node, root) {
  // eslint-disable-next-line no-param-reassign
  node.start_ms = timestampToMs(node.timestamp) - timestampToMs(root.timestamp);
  node.children.forEach((child) => setNodeStartTs(child, root));
}

export const SPANS_LIMIT = 2000;

export function mapTraceToSpanTrees(trace) {
  const nodes = {};

  const hasError = (span) => span.status_code === 'STATUS_CODE_ERROR';

  const spanToNode = (span) => ({
    timestamp: span.timestamp,
    span_id: span.span_id,
    operation: span.operation,
    service: span.service_name,
    duration_ms: convertNanoToMs(span.duration_nano),
    children: [],
    hasError: hasError(span),
  });

  const pruned = trace.spans.length > SPANS_LIMIT;
  const prunedSpansList = trace.spans.slice(0, SPANS_LIMIT);

  prunedSpansList.forEach((s) => {
    nodes[s.span_id] = spanToNode(s);
  });

  const roots = [];

  let incomplete = false;
  let totalErrors = 0;

  // spans are ordered by timestamp, so pruning the list by selecting the first SPANS_LIMIT spans
  // should not produce incorrect trees
  prunedSpansList.forEach((s) => {
    const node = nodes[s.span_id];
    const parentId = s.parent_span_id;
    if (nodes[parentId]) {
      nodes[parentId].children.push(node);
    } else {
      /**
       * in this case the node either
       *  a) is a valid root (parentId === '')
       *  b) has a parent which is missing (parentId !== '' && nodes[parentId] === null), in which case we consider it a root
       *     of an incomplete tree
       */
      roots.push(node);
      if (parentId !== '') {
        incomplete = true;
      }
    }
    if (hasError(s)) {
      totalErrors += 1;
    }
  });
  if (roots.length > 1) {
    // if there is more than one roots it means we have discontinuous data and trace is “incomplete”
    incomplete = true;
  }
  // in case of multiple trees, we want to sort them by timestamp
  roots.sort((a, b) => a.timestamp_nano - b.timestamp_nano);
  if (roots[0]) {
    // and use the first root's timestamp as baseline for the other trees
    roots.forEach((root) => setNodeStartTs(root, roots[0]));
  }
  return { roots, incomplete, pruned, totalErrors };
}
