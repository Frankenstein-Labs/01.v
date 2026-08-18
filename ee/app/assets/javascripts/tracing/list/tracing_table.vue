<script>
import { GlTable, GlBadge, GlIcon } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { FULL_DATE_TIME_FORMAT } from '~/observability/constants';
import { formatTraceDuration } from '../trace_utils';

export default {
  name: 'TracingTable',
  i18n: {
    title: s__('Tracing|Traces'),
    inProgress: s__('Tracing|In progress'),
  },
  fields: [
    {
      key: 'timestamp',
      label: s__('Tracing|Date'),
      tdAttr: { 'data-testid': 'trace-timestamp' },
    },
    {
      key: 'service_name',
      label: s__('Tracing|Service'),
      tdAttr: { 'data-testid': 'trace-service' },
      tdClass: 'gl-break-anywhere',
    },
    {
      key: 'operation',
      label: s__('Tracing|Operation'),
      tdAttr: { 'data-testid': 'trace-operation' },
      tdClass: 'gl-break-anywhere',
    },
    {
      key: 'duration',
      label: s__('Tracing|Duration'),
      thClass: 'gl-w-3/20',
      tdAttr: { 'data-testid': 'trace-duration' },
    },
  ],
  components: {
    GlTable,
    GlBadge,
    GlIcon,
  },
  props: {
    traces: {
      required: true,
      type: Array,
    },
    highlightedTraceId: {
      required: false,
      type: String,
      default: null,
    },
  },
  emits: ['trace-clicked'],
  computed: {
    formattedTraces() {
      return this.traces.map((x) => ({
        ...x,
        timestamp: formatDate(x.timestamp, FULL_DATE_TIME_FORMAT),
        duration: formatTraceDuration(x.duration_nano),
      }));
    },
  },
  methods: {
    onRowClicked(item, _index, event) {
      this.$emit('trace-clicked', { traceId: item.trace_id, clickEvent: event });
    },
    rowClass(item, type) {
      if (!item || type !== 'row') return '';
      if (item.trace_id === this.highlightedTraceId) return 'gl-bg-alpha-dark-8';
      return 'hover:gl-bg-alpha-dark-8';
    },
    matchesBadgeContent(item) {
      const spans = n__('Tracing|%d span', 'Tracing|%d spans', item.total_spans);
      if (
        item.total_spans === item.matched_span_count ||
        !Number.isInteger(item.matched_span_count) ||
        item.in_progress
      ) {
        return spans;
      }
      const matches = n__('Tracing|%d match', 'Tracing|%d matches', item.matched_span_count);
      return `${spans} / ${matches}`;
    },
    errorBadgeContent(item) {
      return n__('Tracing|%d error', 'Tracing|%d errors', item.error_span_count);
    },
    hasError(item) {
      return item.error_span_count > 0;
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-my-5 gl-block @md/panel:!gl-hidden">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="formattedTraces"
      :fields="$options.fields"
      fixed
      stacked="md"
      :tbody-tr-class="rowClass"
      selectable
      select-mode="single"
      selected-variant=""
      :tbody-tr-attr="{ 'data-testid': 'trace-row' }"
      @row-clicked="onRowClicked"
    >
      <template #cell(timestamp)="{ item }">
        {{ item.timestamp }}
        <div class="gl-mt-4 gl-flex">
          <gl-badge variant="info">{{ matchesBadgeContent(item) }}</gl-badge>
          <gl-badge v-if="item.in_progress" variant="warning" class="gl-ml-3">{{
            $options.i18n.inProgress
          }}</gl-badge>
          <gl-badge v-if="hasError(item)" variant="danger" class="gl-ml-2">
            <gl-icon name="status-alert" class="gl-mr-2" variant="danger" />
            {{ errorBadgeContent(item) }}
          </gl-badge>
        </div>
      </template>
    </gl-table>
  </div>
</template>
