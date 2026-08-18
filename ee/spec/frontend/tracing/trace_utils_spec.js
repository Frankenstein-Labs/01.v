import {
  mapTraceToSpanTrees,
  formatDurationMs,
  formatTraceDuration,
  assignColorToServices,
  SPANS_LIMIT,
} from 'ee/tracing/trace_utils';
import { createMockTrace } from './mock_data';

describe('trace_utils', () => {
  describe('formatDurationMs', () => {
    it.each`
      input      | output              | description
      ${123}     | ${'123ms'}          | ${'format as milliseconds only'}
      ${0.1234}  | ${'0.12ms'}         | ${'format as milliseconds only'}
      ${5000}    | ${'5s'}             | ${'format as seconds only'}
      ${60000}   | ${'1m'}             | ${'format as minutes only'}
      ${3600000} | ${'1h'}             | ${'format as hours only'}
      ${3660}    | ${'3s 660ms'}       | ${'format as seconds and ms'}
      ${121000}  | ${'2m 1s'}          | ${'format as minutes and seconds'}
      ${120100}  | ${'2m 100ms'}       | ${'format as minutes and ms'}
      ${7200020} | ${'2h 20ms'}        | ${'format as hours and ms'}
      ${7260000} | ${'2h 1m'}          | ${'format as hours and minutes'}
      ${3605000} | ${'1h 5s'}          | ${'format as hours and seconds'}
      ${3665000} | ${'1h 1m 5s'}       | ${'format as hours, minutes, and seconds'}
      ${3665123} | ${'1h 1m 5s 123ms'} | ${'format as hours, minutes, seconds, and milliseconds'}
      ${0}       | ${'0ms'}            | ${'handle zero duration'}
      ${-1000}   | ${'0ms'}            | ${'handle negative duration'}
    `('should format $input as $description', ({ input, output }) => {
      expect(formatDurationMs(input)).toBe(output);
    });
  });

  describe('formatTraceDuration', () => {
    it('formats the trace duration nano value', () => {
      expect(formatTraceDuration(5737516022863)).toBe('1h 35m 37s 516ms');
      expect(formatTraceDuration(496896)).toBe('0.50ms');
      expect(formatTraceDuration(9250)).toBe('0.01ms');
    });
  });

  describe('assignColorToService', () => {
    it('should assign the right palette', () => {
      const trace = createMockTrace(31);

      expect(assignColorToServices(trace)).toEqual({
        'service-0': 'gl-bg-data-viz-blue-500',
        'service-1': 'gl-bg-data-viz-orange-500',
        'service-2': 'gl-bg-data-viz-aqua-500',
        'service-3': 'gl-bg-data-viz-green-500',
        'service-4': 'gl-bg-data-viz-magenta-500',
        'service-5': 'gl-bg-data-viz-blue-600',
        'service-6': 'gl-bg-data-viz-orange-600',
        'service-7': 'gl-bg-data-viz-aqua-600',
        'service-8': 'gl-bg-data-viz-green-600',
        'service-9': 'gl-bg-data-viz-magenta-600',
        'service-10': 'gl-bg-data-viz-blue-700',
        'service-11': 'gl-bg-data-viz-orange-700',
        'service-12': 'gl-bg-data-viz-aqua-700',
        'service-13': 'gl-bg-data-viz-green-700',
        'service-14': 'gl-bg-data-viz-magenta-700',
        'service-15': 'gl-bg-data-viz-blue-800',
        'service-16': 'gl-bg-data-viz-orange-800',
        'service-17': 'gl-bg-data-viz-aqua-800',
        'service-18': 'gl-bg-data-viz-green-800',
        'service-19': 'gl-bg-data-viz-magenta-800',
        'service-20': 'gl-bg-data-viz-blue-900',
        'service-21': 'gl-bg-data-viz-orange-900',
        'service-22': 'gl-bg-data-viz-aqua-900',
        'service-23': 'gl-bg-data-viz-green-900',
        'service-24': 'gl-bg-data-viz-magenta-900',
        'service-25': 'gl-bg-data-viz-blue-950',
        'service-26': 'gl-bg-data-viz-orange-950',
        'service-27': 'gl-bg-data-viz-aqua-950',
        'service-28': 'gl-bg-data-viz-green-950',
        'service-29': 'gl-bg-data-viz-magenta-950',
        // restart pallete
        'service-30': 'gl-bg-data-viz-blue-500',
      });
    });
  });

  describe('mapTraceToSpanTrees', () => {
    const secsToNano = (secs) => secs * 1e9;
    const secsToMs = (secs) => secs * 1e3;

    // eslint-disable-next-line max-params
    const createMockSpan = (spanId, parentId, durationNano, timestamp, hasError = false) => ({
      timestamp,
      span_id: spanId,
      trace_id: 'fake-trace',
      service_name: 'fake-service',
      operation: 'fake-operation',
      duration_nano: durationNano,
      parent_span_id: parentId,
      status_code: hasError ? 'STATUS_CODE_ERROR' : undefined,
    });

    it('should map a trace data to tree data', () => {
      const trace = {
        spans: [
          createMockSpan('SPAN-1', '', secsToNano(10), '2023-08-07T15:03:00'),
          createMockSpan('SPAN-2', 'SPAN-1', secsToNano(9), '2023-08-07T15:03:01'),
          createMockSpan('SPAN-3', 'SPAN-2', secsToNano(8), '2023-08-07T15:03:02', true),
          createMockSpan('SPAN-4', 'SPAN-2', secsToNano(7), '2023-08-07T15:03:03', true),
        ],
        duration_nano: 3000000,
      };

      expect(mapTraceToSpanTrees(trace)).toEqual({
        totalErrors: 2,
        incomplete: false,
        pruned: false,
        roots: [
          {
            duration_ms: secsToMs(10),
            operation: 'fake-operation',
            service: 'fake-service',
            span_id: 'SPAN-1',
            start_ms: 0,
            timestamp: '2023-08-07T15:03:00',
            hasError: false,
            children: [
              {
                duration_ms: secsToMs(9),
                operation: 'fake-operation',
                service: 'fake-service',
                span_id: 'SPAN-2',
                start_ms: secsToMs(1),
                timestamp: '2023-08-07T15:03:01',
                hasError: false,
                children: [
                  {
                    children: [],
                    duration_ms: secsToMs(8),
                    operation: 'fake-operation',
                    service: 'fake-service',
                    span_id: 'SPAN-3',
                    start_ms: secsToMs(2),
                    timestamp: '2023-08-07T15:03:02',
                    hasError: true,
                  },
                  {
                    children: [],
                    duration_ms: secsToMs(7),
                    operation: 'fake-operation',
                    service: 'fake-service',
                    span_id: 'SPAN-4',
                    start_ms: secsToMs(3),
                    timestamp: '2023-08-07T15:03:03',
                    hasError: true,
                  },
                ],
              },
            ],
          },
        ],
      });
    });

    it('should handle missing roots', () => {
      expect(
        mapTraceToSpanTrees({
          spans: [
            createMockSpan('SPAN-2', 'SPAN-1', secsToNano(9), '2023-08-07T15:03:01'),
            createMockSpan('SPAN-3', 'SPAN-2', secsToNano(8), '2023-08-07T15:03:02'),
            createMockSpan('SPAN-4', 'SPAN-2', secsToNano(7), '2023-08-07T15:03:03'),
          ],
          duration_nano: 3000000,
        }),
      ).toEqual({
        incomplete: true,
        totalErrors: 0,
        pruned: false,
        roots: [
          {
            duration_ms: secsToMs(9),
            operation: 'fake-operation',
            service: 'fake-service',
            span_id: 'SPAN-2',
            start_ms: 0,
            timestamp: '2023-08-07T15:03:01',
            hasError: false,
            children: [
              {
                children: [],
                duration_ms: secsToMs(8),
                operation: 'fake-operation',
                service: 'fake-service',
                span_id: 'SPAN-3',
                start_ms: secsToMs(1),
                timestamp: '2023-08-07T15:03:02',
                hasError: false,
              },
              {
                children: [],
                duration_ms: secsToMs(7),
                operation: 'fake-operation',
                service: 'fake-service',
                span_id: 'SPAN-4',
                start_ms: secsToMs(2),
                timestamp: '2023-08-07T15:03:03',
                hasError: false,
              },
            ],
          },
        ],
      });
    });

    it('should handle multiple roots', () => {
      expect(
        mapTraceToSpanTrees({
          spans: [
            createMockSpan('SPAN-1', '', secsToNano(10), '2023-08-07T15:03:00'),
            createMockSpan('SPAN-2', 'SPAN-1', secsToNano(5), '2023-08-07T15:03:05'),
            createMockSpan('SPAN-3', '', secsToNano(10), '2023-08-07T15:03:03'),
            createMockSpan('SPAN-4', 'SPAN-3', secsToNano(4), '2023-08-07T15:03:04'),
          ],
          duration_nano: 3000000,
        }),
      ).toEqual({
        incomplete: true,
        totalErrors: 0,
        pruned: false,
        roots: [
          {
            duration_ms: secsToMs(10),
            operation: 'fake-operation',
            service: 'fake-service',
            span_id: 'SPAN-1',
            start_ms: 0,
            timestamp: '2023-08-07T15:03:00',
            hasError: false,
            children: [
              {
                children: [],
                duration_ms: secsToMs(5),
                operation: 'fake-operation',
                service: 'fake-service',
                span_id: 'SPAN-2',
                start_ms: secsToMs(5),
                timestamp: '2023-08-07T15:03:05',
                hasError: false,
              },
            ],
          },
          {
            duration_ms: secsToMs(10),
            operation: 'fake-operation',
            service: 'fake-service',
            span_id: 'SPAN-3',
            start_ms: secsToMs(3),
            timestamp: '2023-08-07T15:03:03',
            hasError: false,
            children: [
              {
                children: [],
                duration_ms: secsToMs(4),
                operation: 'fake-operation',
                service: 'fake-service',
                span_id: 'SPAN-4',
                start_ms: secsToMs(4),
                timestamp: '2023-08-07T15:03:04',
                hasError: false,
              },
            ],
          },
        ],
      });
    });

    it('should prune the spans list if there are more than SPANS_LIMIT spans', () => {
      const trace = createMockTrace(SPANS_LIMIT + 1);

      const { roots, pruned } = mapTraceToSpanTrees(trace);

      expect(pruned).toBe(true);
      expect(roots).toHaveLength(1);
      expect(roots[0].children).toHaveLength(SPANS_LIMIT - 1);
    });
  });
});
