<script>
import { GlSprintf } from '@gitlab/ui';
import {
  CRITICAL,
  HIGH,
  MEDIUM,
  LOW,
  INFO,
  UNKNOWN,
  SEVERITY_COUNT_LIMIT,
} from 'ee/vulnerabilities/constants';
import { s__, sprintf } from '~/locale';

const SEVERITY_ITEMS = [
  { key: 'critical', cssClass: 'severity-text-critical' },
  { key: 'high', cssClass: 'severity-text-high' },
  { key: 'other' },
];

export default {
  name: 'SummaryHighlights',
  components: {
    GlSprintf,
  },
  i18n: {
    noVulnerabilities: s__('SecurityReports|0 vulnerabilities'),
    severityMessage: s__(
      'ciReport|%{criticalStart}%{criticalCount} critical%{criticalEnd}, %{highStart}%{highCount} high%{highEnd}, and %{otherStart}%{otherCount} others%{otherEnd}',
    ),
  },
  props: {
    /**
     * If provided, this will display only the count for the given severity.
     */
    showSingleSeverity: {
      type: String,
      required: false,
      default: '',
      validator: (severity) =>
        !severity || [CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN].includes(severity),
    },
    highlights: {
      type: Object,
      required: true,
      validator: (highlights) =>
        [CRITICAL, HIGH].every((requiredField) => {
          if (typeof highlights[requiredField] === 'undefined') {
            return true;
          }

          return Number.isInteger(highlights[requiredField]);
        }),
    },
    capped: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    criticalSeverityCount() {
      return this.formattedCounts(this.highlights[CRITICAL] ?? 0);
    },
    highSeverityCount() {
      return this.formattedCounts(this.highlights[HIGH] ?? 0);
    },
    otherSeverityCount() {
      if (typeof this.highlights.other !== 'undefined') {
        return this.formattedCounts(this.highlights.other);
      }

      let totalCounts = 0;
      let isCapped = false;

      [MEDIUM, LOW, INFO, UNKNOWN].forEach((severity) => {
        const count = this.highlights[severity];

        if (count) {
          totalCounts += count;
        }

        if (this.capped && count > SEVERITY_COUNT_LIMIT) {
          isCapped = true;
        }
      });

      return isCapped ? this.formattedCounts(totalCounts) : totalCounts;
    },
    severityItems() {
      const counts = {
        critical: this.criticalSeverityCount,
        high: this.highSeverityCount,
        other: this.otherSeverityCount,
      };

      return SEVERITY_ITEMS.map((item) => {
        const count = counts[item.key];
        return {
          ...item,
          count,
          cssClass: this.getCssClass(item, count),
        };
      });
    },
    totalCount() {
      return [this.criticalSeverityCount, this.highSeverityCount, this.otherSeverityCount].reduce(
        (sum, count) => sum + (parseInt(count, 10) || 0),
        0,
      );
    },
    hasNoVulnerabilities() {
      return this.totalCount === 0;
    },
    singleSeverityCount() {
      return this.highlights[this.showSingleSeverity] ?? 0;
    },
    severityMessage() {
      return sprintf(
        this.$options.i18n.severityMessage,
        {
          criticalCount: this.criticalSeverityCount,
          highCount: this.highSeverityCount,
          otherCount: this.otherSeverityCount,
        },
        false,
      );
    },
  },
  methods: {
    getCssClass(item, count) {
      if (this.isPositiveCount(count) && item.cssClass) {
        return item.cssClass;
      }

      return 'gl-text-subtle';
    },
    formattedCounts(count) {
      if (this.capped) {
        return count > SEVERITY_COUNT_LIMIT
          ? sprintf(s__('SecurityReports|%{count}+'), { count: SEVERITY_COUNT_LIMIT })
          : count;
      }

      return count;
    },
    isPositiveCount(count) {
      return parseInt(count, 10) > 0;
    },
    emphasisTag(count) {
      if (this.isPositiveCount(count)) {
        return 'strong';
      }

      return 'span';
    },
  },
};
</script>

<template>
  <div class="gl-text-sm">
    <component
      :is="emphasisTag(singleSeverityCount)"
      v-if="showSingleSeverity"
      :class="`severity-text-${showSingleSeverity}`"
    >
      {{ formattedCounts(singleSeverityCount) }}
      {{ n__('vulnerability', 'vulnerabilities', singleSeverityCount) }}
    </component>

    <span v-else-if="hasNoVulnerabilities" class="gl-text-subtle">
      {{ $options.i18n.noVulnerabilities }}
    </span>

    <gl-sprintf v-else :message="severityMessage">
      <template v-for="item in severityItems" #[item.key]="{ content }">
        <component
          :is="emphasisTag(item.count)"
          :key="item.key"
          :class="item.cssClass"
          :data-testid="item.key"
          >{{ content }}</component
        >
      </template>
    </gl-sprintf>
  </div>
</template>
