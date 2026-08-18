<script>
import { GlDashboardPanel, GlLink, GlSprintf, GlTruncate } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { n__, s__, sprintf } from '~/locale';
import { SEVERITY_LEVELS_KEYS, SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { constructVulnerabilitiesReportWithFiltersPath } from 'ee/security_dashboard/utils/chart_utils';

export default {
  name: 'VulnerabilitiesForSeverityPanel',
  components: {
    GlDashboardPanel,
    GlSingleStat,
    GlLink,
    GlSprintf,
    GlTruncate,
  },
  inject: ['securityVulnerabilitiesPath'],
  props: {
    severity: {
      type: String,
      required: true,
      validator: (value) => SEVERITY_LEVELS_KEYS.includes(value),
    },
    count: {
      type: Number,
      required: false,
      default: null,
    },
    medianAge: {
      type: Number,
      required: false,
      default: null,
    },
    // The active filters from the group or project security dashboard. May be empty or contain
    // `projectId`, `reportType`, and/or `securityAttributesFilters` keys with an array value.
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    error: {
      type: Boolean,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    shouldLinkToReport() {
      return Boolean(this.securityVulnerabilitiesPath);
    },
    title() {
      return SEVERITY_LEVELS[this.severity];
    },
    icon() {
      if (this.error) {
        return 'error';
      }

      return `severity-${this.severity}`;
    },
    iconClass() {
      if (this.error) {
        return 'gl-text-danger';
      }

      return `gl-mr-3 severity-text-${this.severity}`;
    },
    borderColorClass() {
      if (this.error) {
        return 'gl-border-t-red-500';
      }
      return '';
    },
    link() {
      return constructVulnerabilitiesReportWithFiltersPath({
        securityVulnerabilitiesPath: this.securityVulnerabilitiesPath,
        seriesId: this.severity.toUpperCase(),
        filterKey: 'severity',
        additionalFilters: this.filters,
      });
    },
    hasMedianAge() {
      return this.medianAge !== null;
    },
    infoPopover() {
      const message = this.hasMedianAge
        ? s__(
            'SecurityReports|Total number of %{boldStart}open%{boldEnd} %{severity} vulnerabilities and their median amount of time open. Select the number to see the open vulnerabilities in the vulnerability report.',
          )
        : s__(
            'SecurityReports|Total number of %{boldStart}open%{boldEnd} %{severity} vulnerabilities. Select the number to see the open vulnerabilities in the vulnerability report.',
          );
      return sprintf(message, { severity: this.title?.toLowerCase() });
    },
    medianAgeBadge() {
      const days = Math.round(this.medianAge);
      return sprintf(
        n__('SecurityReports|Median: %{days} day', 'SecurityReports|Median: %{days} days', days),
        { days },
      );
    },
  },
};
</script>

<template>
  <gl-dashboard-panel
    :title="title"
    :title-icon="icon"
    :title-icon-class="iconClass"
    :loading="loading"
    :show-alert-state="error"
    :border-color-class="borderColorClass"
  >
    <template #body>
      <div v-if="!error" class="-gl-mt-3 gl-flex-col">
        <gl-link
          v-if="shouldLinkToReport"
          :href="link"
          variant="meta"
          target="_blank"
          class="!gl-outline-none"
        >
          <gl-single-stat title="" :value="count" use-delimiters />
        </gl-link>
        <gl-single-stat v-else title="" :value="count" use-delimiters />
        <gl-truncate
          v-if="hasMedianAge"
          :text="medianAgeBadge"
          with-tooltip
          class="gl-text-subtle"
        />
      </div>
      <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
    <template #info-popover-content>
      <gl-sprintf :message="infoPopover">
        <template #bold="{ content }"
          ><strong>{{ content }}</strong></template
        >
      </gl-sprintf>
    </template>
  </gl-dashboard-panel>
</template>
