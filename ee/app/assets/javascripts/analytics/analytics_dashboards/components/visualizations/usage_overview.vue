<script>
import { GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import {
  BACKGROUND_AGGREGATION_DOCS_LINK,
  BACKGROUND_AGGREGATION_WARNING_TITLE,
  ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
} from 'ee/analytics/dashboards/constants';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import SingleStat from '~/analytics/analytics_dashboards/components/visualizations/single_stat.vue';

export default {
  name: 'UsageOverview',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlIcon,
    SingleStat,
    TooltipOnTruncate,
  },
  inject: {
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties -- options prop is part of the standard visualizations API interface, required for consistency across all visualization components
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['set-alerts'],
  computed: {
    avatarAltText() {
      const { fullName } = this.data.namespace;
      return sprintf(__("%{name}'s avatar"), { name: fullName });
    },
  },
  mounted() {
    if (!this.overviewCountsAggregationEnabled) {
      const { description, descriptionLink, backgroundAggregationNoData } = this.$options.i18n;
      this.$emit('set-alerts', {
        title: this.$options.i18n.backgroundAggregationWarningTitle,
        description: backgroundAggregationNoData,
        warnings: [{ description, link: descriptionLink }],
        canRetry: false,
      });
    }
  },
  methods: {
    displayValue(value) {
      if (value > 0) return value;
      return this.overviewCountsAggregationEnabled ? 0 : '-';
    },
  },
  i18n: {
    backgroundAggregationWarningTitle: BACKGROUND_AGGREGATION_WARNING_TITLE,
    description: ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
    descriptionLink: BACKGROUND_AGGREGATION_DOCS_LINK,
    backgroundAggregationNoData: __('No data available'),
  },
};
</script>
<template>
  <div class="gl-font-size-sm gl-flex gl-flex-row">
    <div
      v-if="data.namespace"
      data-testid="usage-overview-namespace"
      class="gl-mr-9 gl-flex gl-min-w-34 gl-max-w-75 gl-items-center gl-gap-3"
    >
      <gl-avatar
        shape="rect"
        :src="data.namespace.avatarUrl"
        :size="48"
        :entity-name="data.namespace.fullName"
        :entity-id="data.namespace.id"
        :fallback-on-error="true"
        :alt="avatarAltText"
      />

      <div class="gl-min-w-0 gl-leading-24">
        <span class="gl-mb-1 gl-block gl-text-base gl-font-normal gl-text-subtle">{{
          data.namespace.namespaceType
        }}</span>
        <div class="gl-flex gl-items-center gl-gap-2">
          <tooltip-on-truncate
            :title="data.namespace.fullName"
            class="gl-truncate gl-text-size-h2 gl-font-bold"
            boundary="viewport"
            >{{ data.namespace.fullName }}</tooltip-on-truncate
          >
          <button
            v-gl-tooltip.viewport
            data-testid="namespace-visibility-button"
            class="gl-min-w-5 gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
            :title="data.namespace.visibilityLevelTooltip"
            :aria-label="data.namespace.visibilityLevelTooltip"
          >
            <gl-icon variant="subtle" :name="data.namespace.visibilityLevelIcon" />
          </button>
        </div>
      </div>
    </div>

    <div
      v-for="metric in data.metrics"
      :key="metric.identifier"
      class="gl-flex-shrink-0 gl-pr-9"
      :data-testid="`usage-overview-metric-${metric.identifier}`"
    >
      <single-stat :data="displayValue(metric.value)" :options="metric.options" />
    </div>
  </div>
</template>
