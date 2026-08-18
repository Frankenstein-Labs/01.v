<script>
import { camelCase } from 'lodash-es';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { GRAY_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__ } from '~/locale';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';
import {
  getSeverityColors,
  formatVulnerabilitiesBySeries,
  constructVulnerabilitiesReportWithFiltersPath,
} from 'ee/security_dashboard/utils/chart_utils';

export default {
  name: 'VulnerabilitiesByIdentifierChart',
  components: {
    GlStackedColumnChart,
    GlLink,
    GlSprintf,
    GlChartSeriesLabel,
  },
  inject: ['securityVulnerabilitiesPath'],
  props: {
    // The response of the `vulnerabilitiesByIdentifier` field from the GraphQL query in the parent panel component.
    vulnerabilitiesByIdentifier: {
      type: Array,
      required: true,
    },
    // The active filters from the group or project security dashboard. May be empty or contain
    // `projectId`, `reportType`, and/or `securityAttributesFilters` keys with an array value.
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      severityColors: {},
    };
  },
  computed: {
    shouldLinkToReport() {
      return Boolean(this.securityVulnerabilitiesPath);
    },
    customPalette() {
      return this.bars.map((bar) => this.getColor(bar.id));
    },
    bars() {
      return formatVulnerabilitiesBySeries(this.vulnerabilitiesByIdentifier, {
        groupBy: 'severity',
        isStacked: true,
      });
    },
    labels() {
      return this.vulnerabilitiesByIdentifier.map((identifier) => identifier.name);
    },
    key() {
      return this.bars.map((b) => b.id).join('-');
    },
  },
  mounted() {
    this.setSeverityColors();
    listenSystemColorSchemeChange(this.setSeverityColors);
  },
  destroyed() {
    removeListenerSystemColorSchemeChange(this.setSeverityColors);
  },
  methods: {
    getColor(id) {
      const normalizedId = camelCase(id);
      return this.severityColors[normalizedId] || GRAY_500;
    },
    setSeverityColors() {
      this.severityColors = getSeverityColors();
    },
    vulnerabilitiesReportWithFiltersPath(identifier, severity) {
      return constructVulnerabilitiesReportWithFiltersPath({
        securityVulnerabilitiesPath: this.securityVulnerabilitiesPath,
        seriesId: identifier,
        filterKey: 'identifier',
        additionalFilters: {
          ...this.filters,
          severity: severity?.toUpperCase(),
        },
      });
    },
    getUrl(cwe) {
      return this.vulnerabilitiesByIdentifier.find(({ name }) => name === cwe)?.url;
    },
  },
  chartOptions: {
    animation: false,
    xAxis: {
      axisLabel: {
        interval: 0,
      },
    },
    yAxis: [
      {
        minInterval: 1,
      },
    ],
    // Note: This is a workaround to remove the extra whitespace when the chart has no title
    // Once https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2199 has been fixed, this can be removed
    grid: {
      left: '10px',
      right: '10px',
      bottom: '10px',
      top: '10px',
      containLabel: true,
    },
  },
  i18n: {
    mitreDefinition: s__(
      'SecurityReports|To learn more about this CWE, view the %{linkStart}MITRE definition.%{linkEnd}',
    ),
  },
};
</script>

<template>
  <gl-stacked-column-chart
    ref="wrapper"
    :key="key"
    :bars="bars"
    :option="$options.chartOptions"
    :group-by="labels"
    :custom-palette="customPalette"
    :include-legend-avg-max="false"
    presentation="stacked"
    x-axis-type="category"
    :x-axis-title="''"
    :y-axis-title="''"
    responsive
    height="auto"
    click-to-pin-tooltip
  >
    <template #tooltip-title="{ params }">
      <gl-link
        v-if="params && shouldLinkToReport"
        :href="vulnerabilitiesReportWithFiltersPath(params.value)"
        target="_blank"
        >{{ params.value }}</gl-link
      >
      <span v-else-if="params">{{ params.value }}</span>
    </template>
    <template #tooltip-content="{ params }">
      <div
        v-for="{ seriesName, value } in params && params.seriesData"
        :key="seriesName"
        class="gl-flex gl-justify-between"
      >
        <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="getColor(seriesName)">
          {{ seriesName }}
        </gl-chart-series-label>
        <gl-link
          v-if="shouldLinkToReport && value"
          :href="vulnerabilitiesReportWithFiltersPath(params.value, seriesName)"
          target="_blank"
          class="gl-font-bold"
          >{{ value }}</gl-link
        >
        <span v-else class="gl-font-bold">{{ value }}</span>
      </div>
      <div
        v-if="params && getUrl(params.value)"
        class="gl-mt-3 gl-max-w-26"
        data-testid="mitre-label"
      >
        <gl-sprintf :message="$options.i18n.mitreDefinition">
          <template #link="{ content }">
            <gl-link :href="getUrl(params.value)" target="_blank" show-external-icon>{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
    </template>
  </gl-stacked-column-chart>
</template>
