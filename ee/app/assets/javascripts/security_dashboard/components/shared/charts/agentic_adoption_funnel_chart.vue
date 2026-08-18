<script>
import { graphic } from 'echarts';
import { GlChart } from '@gitlab/ui/src/charts';
import { GL_COLOR_PURPLE_100, GL_COLOR_PURPLE_900 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__ } from '~/locale';
import { DASHBOARD_TYPE_GROUP } from 'ee/security_dashboard/constants';
import AgenticAdoptionFunnelEmptyState from './agentic_adoption_funnel_empty_state.vue';
import AgenticAdoptionFunnelStage from './agentic_adoption_funnel_stage.vue';

const GRADIENT = new graphic.LinearGradient(0, 0, 1, 0, [
  { offset: 0, color: GL_COLOR_PURPLE_100 },
  { offset: 1, color: GL_COLOR_PURPLE_900 },
]);

// "Illustrative" drop ratio for curve in empty state
const EMPTY_STAGE_DROP_RATIO = 0.4;

// Minimum plotted height (as a fraction of the largest stage) so that stages with a small but
// non-zero count stay visible curve.
const MIN_VISIBLE_RATIO = 0.07;

// Backend status: funnel stage is available (count populated, or null while still pending)
const AVAILABLE = 'AVAILABLE';
// Backend status: stage is unavailable because GitLab Duo is disabled
const UNAVAILABLE_DUO_DISABLED = 'UNAVAILABLE_DUO_DISABLED';
// Backend status: stage is unavailable because the AI feature is disabled, but a user can enable it
const UNAVAILABLE_DISABLED = 'UNAVAILABLE_DISABLED';
// Backend status: stage is unavailable only because an upstream stage is off (e.g. Vulnerability
// Resolution needs False Positive Detection).
const UNAVAILABLE_UPSTREAM_DISABLED = 'UNAVAILABLE_UPSTREAM_DISABLED';

// Derived display state for a funnel stage
const STAGE_SHOWN = 'shown'; // available and has data -> rendered in the chart
const STAGE_EMPTY = 'empty'; // pending or upstream-disabled -> nothing rendered, only affects layout
const STAGE_DISABLED = 'disabled'; // feature off / unlicensed -> empty state card shown

export default {
  name: 'AgenticAdoptionFunnelChart',
  components: {
    GlChart,
    AgenticAdoptionFunnelEmptyState,
    AgenticAdoptionFunnelStage,
  },
  props: {
    namespace: {
      type: String,
      required: true,
    },
    detectedVulnerabilities: {
      type: Object,
      required: true,
    },
    truePositives: {
      type: Object,
      required: true,
    },
    createdMergeRequests: {
      type: Object,
      required: true,
    },
    mergedMergeRequests: {
      type: Object,
      required: true,
    },
  },
  computed: {
    truePositivesState() {
      return this.stageState(this.truePositives);
    },
    mergeRequestsState() {
      return this.stageState(this.createdMergeRequests);
    },
    showTruePositives() {
      return this.truePositivesState === STAGE_SHOWN;
    },
    showMergeRequests() {
      return this.mergeRequestsState === STAGE_SHOWN;
    },
    showFalsePositiveEmptyState() {
      return this.truePositivesState === STAGE_DISABLED;
    },
    showVulnerabilityResolutionEmptyState() {
      return this.mergeRequestsState === STAGE_DISABLED;
    },
    showEmptyStates() {
      return this.showFalsePositiveEmptyState || this.showVulnerabilityResolutionEmptyState;
    },
    falsePositiveDisabledDescription() {
      return this.disabledDescription(
        this.truePositives.status,
        this.$options.i18n.enableFalsePositiveInProjectsDescription,
      );
    },
    vulnerabilityResolutionDisabledDescription() {
      return this.disabledDescription(
        this.createdMergeRequests.status,
        this.$options.i18n.enableVulnerabilityResolutionInProjectsDescription,
      );
    },
    layoutClasses() {
      if (this.showTruePositives) {
        // all stages shown
        if (this.showMergeRequests) {
          return { chart: 'gl-w-full' };
        }
        // created and merged MRs not shown -> VR empty state shown
        return { chart: 'gl-w-2/3', empty: 'gl-w-1/3' };
      }
      if (this.mergeRequestsState === STAGE_EMPTY) {
        return { chart: 'gl-w-1/2', empty: 'gl-w-1/2' };
      }
      return { chart: 'gl-w-1/3', empty: 'gl-w-2/3' };
    },
    chartEndRatio() {
      const total = this.detectedVulnerabilities.count;
      if (!total) return 0;

      const lastValue = this.chartData.at(-1)[1];
      return lastValue / total;
    },
    falsePositiveEndRatio() {
      return this.chartEndRatio * EMPTY_STAGE_DROP_RATIO;
    },
    vulnerabilityResolutionStartRatio() {
      return this.showTruePositives ? this.chartEndRatio : this.falsePositiveEndRatio;
    },
    chartData() {
      const rawPoints = [['detected_vulnerabilities', this.detectedVulnerabilities.count]];
      if (this.showTruePositives) {
        rawPoints.push(['true_positives', this.truePositives.count]);
      }
      if (this.showMergeRequests) {
        rawPoints.push(
          ['created_merge_requests', this.createdMergeRequests.count],
          ['merged_merge_requests', this.mergedMergeRequests.count],
        );
      }

      // Give stages with a small but non-zero count a minimum plotted height so the curve stays
      // visible next to much larger stages.
      const minVisibleValue = this.detectedVulnerabilities.count * MIN_VISIBLE_RATIO;
      const points = rawPoints.map(([label, value]) => [
        label,
        value > 0 ? Math.max(value, minVisibleValue) : value,
      ]);

      // n stages only draw n-1 line segments, so we duplicate a point to get one
      // wave drop per stage column. Duplicating the last (not the first) keeps the
      // final stage flat, signalling resolution (the curve rolls to a stop).
      const [lastLabel, lastValue] = points[points.length - 1];
      points.push([`${lastLabel}_2`, lastValue]);
      return points;
    },
    chartOptions() {
      return {
        grid: {
          left: '0px',
          right: '0px',
          bottom: '0px',
          top: '0px',
        },
        xAxis: {
          type: 'category',
          show: false,
          boundaryGap: false,
          axisPointer: {
            type: 'line',
          },
        },
        yAxis: {
          type: 'value',
          show: false,
          max: 'dataMax',
        },
        series: [
          {
            type: 'line',
            smooth: 0.3,
            symbol: 'none',
            data: this.chartData,
            silent: true,
            cursor: 'default',
            emphasis: {
              disabled: true,
            },
            lineStyle: {
              opacity: 0,
            },
            areaStyle: {
              color: GRADIENT,
            },
            // White vertical dividers between the stages (at points 1, 2 and 3).
            markLine: {
              silent: true,
              symbol: 'none',
              label: { show: false },
              lineStyle: {
                color: 'var(--gl-background-color-default)',
                width: 4,
                type: 'solid',
                opacity: 1,
              },
              data: [{ xAxis: 1 }, { xAxis: 2 }, { xAxis: 3 }],
            },
          },
        ],
      };
    },
  },
  methods: {
    stageState({ status, count }) {
      // Blocked only by an upstream stage being off: hide it entirely so the upstream stage's
      // empty state tells the whole story.
      if (status === UNAVAILABLE_UPSTREAM_DISABLED) return STAGE_EMPTY;
      if (status !== AVAILABLE) return STAGE_DISABLED;
      return count === null ? STAGE_EMPTY : STAGE_SHOWN;
    },
    // On a project the empty state points at the one setting to flip, so a viewer who lacks the
    // permission is told who to ask. A group has no such setting: Duo is controlled by a group Owner
    // and the AI features are enabled per project, so each reason gets its own guidance.
    disabledDescription(status, groupFeatureDescription) {
      const { emptyStateDisabledDescription, groupDuoDisabledDescription } = this.$options.i18n;

      if (this.namespace !== DASHBOARD_TYPE_GROUP) return emptyStateDisabledDescription;
      if (status === UNAVAILABLE_DUO_DISABLED) return groupDuoDisabledDescription;
      if (status === UNAVAILABLE_DISABLED) return groupFeatureDescription;

      return emptyStateDisabledDescription;
    },
  },
  i18n: {
    detectedVulnerabilitiesTitle: s__('SecurityReports|Critical & High SAST vulnerabilities'),
    truePositiveTitle: s__('SecurityReports|True positive'),
    falsePositiveDetection: s__('SecurityReports|False Positive Detection'),
    vulnerabilityResolution: s__('SecurityReports|Vulnerability Resolution'),
    falsePositiveTitle: s__('SecurityReports|False Positive Detection turned off'),
    enableFalsePositiveDescription: s__(
      'SecurityReports|AI evaluates for false positives, helping to tune the noise to signal ratio.',
    ),
    createdMergeRequestsTitle: s__('SecurityReports|Vulnerabilities with AI-created MRs'),
    mergedMergeRequestsTitle: s__('SecurityReports|Vulnerabilities fixed'),
    fromAiCreatedMrs: s__('SecurityReports|From AI-created MRs'),
    vulnerabilityResolutionTitle: s__('SecurityReports|Vulnerability Resolution turned off'),
    enableVulnerabilityResolutionDescription: s__(
      'SecurityReports|Reduce time and effort with proposed fixes from AI-created MRs.',
    ),
    emptyStateDisabledDescription: s__(
      'SecurityReports|Ask someone with the Maintainer or Owner role to turn it on.',
    ),
    groupDuoDisabledDescription: s__('SecurityReports|Ask a group Owner to turn it on.'),
    enableFalsePositiveInProjectsDescription: s__(
      'SecurityReports|Enable False Positive Detection on at least 1 project in this group.',
    ),
    enableVulnerabilityResolutionInProjectsDescription: s__(
      'SecurityReports|Enable Vulnerability Resolution on at least 1 project in this group.',
    ),
  },
};
</script>

<template>
  <div class="gl-flex gl-h-full gl-gap-2">
    <div
      class="gl-flex gl-h-full gl-flex-col"
      :class="layoutClasses.chart"
      data-testid="funnel-chart-area"
    >
      <div
        class="gl-grid gl-basis-13 gl-auto-cols-fr gl-grid-flow-col gl-gap-2"
        data-testid="funnel-stage-header-row"
      >
        <agentic-adoption-funnel-stage
          :count="detectedVulnerabilities.count"
          :title="$options.i18n.detectedVulnerabilitiesTitle"
        />
        <agentic-adoption-funnel-stage
          v-if="showTruePositives"
          :count="truePositives.count"
          :title="$options.i18n.truePositiveTitle"
          :description="$options.i18n.falsePositiveDetection"
        />
        <template v-if="showMergeRequests">
          <agentic-adoption-funnel-stage
            :count="createdMergeRequests.count"
            :title="$options.i18n.createdMergeRequestsTitle"
            :description="$options.i18n.vulnerabilityResolution"
          />
          <agentic-adoption-funnel-stage
            :count="mergedMergeRequests.count"
            :title="$options.i18n.mergedMergeRequestsTitle"
            :description="$options.i18n.fromAiCreatedMrs"
          />
        </template>
      </div>

      <div class="gl-min-h-0 gl-grow">
        <gl-chart :options="chartOptions" responsive height="auto" class="gl-h-full gl-w-full" />
      </div>
    </div>

    <div
      v-if="showEmptyStates"
      class="gl-grid gl-auto-cols-fr gl-grid-flow-col gl-gap-2"
      :class="layoutClasses.empty"
      data-testid="funnel-empty-states"
    >
      <agentic-adoption-funnel-empty-state
        v-if="showFalsePositiveEmptyState"
        icon="false-positive"
        :title="$options.i18n.falsePositiveTitle"
        :description="$options.i18n.enableFalsePositiveDescription"
        :can-enable="Boolean(truePositives.canEnable)"
        :disabled-description="falsePositiveDisabledDescription"
        :start-ratio="chartEndRatio"
        :end-ratio="falsePositiveEndRatio"
      />
      <agentic-adoption-funnel-empty-state
        v-if="showVulnerabilityResolutionEmptyState"
        icon="merge-request"
        :title="$options.i18n.vulnerabilityResolutionTitle"
        :description="$options.i18n.enableVulnerabilityResolutionDescription"
        :can-enable="Boolean(createdMergeRequests.canEnable)"
        :disabled-description="vulnerabilityResolutionDisabledDescription"
        :start-ratio="vulnerabilityResolutionStartRatio"
      />
    </div>
  </div>
</template>
