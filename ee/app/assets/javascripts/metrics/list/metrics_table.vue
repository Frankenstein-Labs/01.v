<script>
import { GlTable, GlLabel, GlTooltipDirective, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ingestedAtTimeAgo } from '../utils';
import { METRIC_TYPE } from '../constants';

const MAX_NUM_OF_ATTRIBUTES_SHOWN = 5;

export default {
  name: 'MetricsTable',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    title: s__('ObservabilityMetrics|Metrics'),
    moreAttributes: s__(`ObservabilityMetrics|+%{count} more`),
  },
  fields: [
    {
      key: 'name',
      label: s__('ObservabilityMetrics|Name'),
      tdAttr: { 'data-testid': 'metric-name' },
      tdClass: `gl-break-anywhere`,
    },
    {
      key: 'description',
      label: s__('ObservabilityMetrics|Description'),
      tdAttr: { 'data-testid': 'metric-description' },
      thClass: 'gl-w-6/20',
      tdClass: `gl-break-anywhere`,
    },
    {
      key: 'type',
      label: s__('ObservabilityMetrics|Type'),
      tdAttr: { 'data-testid': 'metric-type' },
      thClass: 'gl-w-2/20',
    },
    {
      key: 'attributes',
      label: s__('ObservabilityMetrics|Dimensions'),
      tdAttr: { 'data-testid': 'metric-attributes' },
      thClass: 'gl-w-6/20',
      tdClass: `gl-break-anywhere`,
    },
    {
      key: 'last_ingested_at',
      label: s__('ObservabilityMetrics|Last ingested'),
      tdAttr: { 'data-testid': 'metric-last-ingested' },
      thClass: 'gl-w-2/20',
    },
  ],
  components: {
    GlTable,
    GlLabel,
    GlSprintf,
  },
  props: {
    metrics: {
      required: true,
      type: Array,
    },
  },
  emits: ['metric-clicked'],
  computed: {
    formattedMetrics() {
      return this.metrics.map((x) => ({
        ...x,
        last_ingested_at: ingestedAtTimeAgo(x.last_ingested_at),
      }));
    },
  },
  methods: {
    labelColor(type) {
      // Colors are taken from the label's colors map: gitlab/app/helpers/labels_helper.rb
      switch (type.toLowerCase()) {
        case METRIC_TYPE.Sum:
          return '#6699cc'; // blue-gray
        case METRIC_TYPE.Guage:
          return '#cd5b45'; // dark-coral
        case METRIC_TYPE.Histogram:
          return '#009966'; // green-cyan
        case METRIC_TYPE.ExponentialHistogram:
          return '#ed9121'; // carrot-orange
        default:
          return '#808080'; // gray
      }
    },
    onRowClicked(item, _index, event) {
      this.$emit('metric-clicked', { metricId: item.name, clickEvent: event });
    },
    metricAttributesText({ attributes }) {
      return attributes.slice(0, MAX_NUM_OF_ATTRIBUTES_SHOWN).join(', ');
    },
    metricAttributesTooltipContent({ attributes }) {
      return attributes.slice(MAX_NUM_OF_ATTRIBUTES_SHOWN).join(', ');
    },
    metricAttributesTruncatedItems({ attributes }) {
      if (attributes.length > MAX_NUM_OF_ATTRIBUTES_SHOWN) {
        return attributes.length - MAX_NUM_OF_ATTRIBUTES_SHOWN;
      }
      return 0;
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-my-5 gl-block @md/panel:!gl-hidden">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="formattedMetrics"
      :fields="$options.fields"
      fixed
      stacked="md"
      :tbody-tr-attr="{ 'data-testid': 'metric-row' }"
      selectable
      select-mode="single"
      selected-variant=""
      class="gl-table-no-top-border"
      @row-clicked="onRowClicked"
    >
      <template #cell(type)="{ item }">
        <gl-label :background-color="labelColor(item.type)" :title="item.type" />
      </template>

      <template #cell(attributes)="{ item }">
        <span>
          {{ metricAttributesText(item) }}
        </span>
        <span
          v-if="metricAttributesTruncatedItems(item) > 0"
          v-gl-tooltip="metricAttributesTooltipContent(item)"
          data-testid="metric-attributes-tooltip"
          class="gl-link hover:gl-underline"
        >
          <gl-sprintf :message="$options.i18n.moreAttributes">
            <template #count>{{ metricAttributesTruncatedItems(item) }}</template>
          </gl-sprintf>
        </span>
      </template>
    </gl-table>
  </div>
</template>
