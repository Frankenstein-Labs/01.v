<script>
import { GlResizeObserverDirective, GlPopover, GlLink } from '@gitlab/ui';
import { generateGrid } from 'ee/security_dashboard/utils/chart_utils';
import { projectSecurityVulnerabilityReportIndexPath } from 'ee/lib/utils/path_helpers/project';
import { s__, sprintf } from '~/locale';

export default {
  directives: {
    GlResizeObserver: GlResizeObserverDirective,
  },
  components: {
    GlPopover,
    GlLink,
  },
  props: {
    riskScores: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      nrCols: 0,
      nrRows: 0,
    };
  },
  computed: {
    gridStyle() {
      return `grid-template-columns: repeat(${this.nrCols}, 1fr); grid-template-rows: repeat(${this.nrRows}, 1fr);`;
    },
  },
  methods: {
    updateGridDimensions({ contentRect: { width, height } }) {
      if (!width || !height) return;

      if (this.riskScores.length === 0) {
        this.nrRows = 0;
        this.nrCols = 0;
        return;
      }

      const { rows, cols } = generateGrid({
        totalItems: this.riskScores.length,
        width,
        height,
      });
      this.nrRows = rows;
      this.nrCols = cols;
    },
    getAriaLabel(riskScore) {
      return sprintf(s__('SecurityReports|Project %{project}, risk score: %{riskScore}'), {
        project: riskScore.project.name,
        riskScore: riskScore.score,
      });
    },
    getRiskRatingLabel(rating) {
      return sprintf(s__('SecurityReports|%{rating} risk score'), {
        rating: this.$options.i18n.ratings[rating],
      });
    },
    getVulnerabilityReportUrl(project) {
      return projectSecurityVulnerabilityReportIndexPath(project.fullPath);
    },
    getTileBgClass(rating) {
      return `risk-score-bg-${rating.toLowerCase()}`;
    },
    getTileTextClass(rating) {
      return `risk-score-tile-text-${rating.toLowerCase()}`;
    },
  },
  i18n: {
    ratings: {
      CRITICAL: s__('SecurityReports|Critical'),
      HIGH: s__('SecurityReports|High'),
      MEDIUM: s__('SecurityReports|Medium'),
      LOW: s__('SecurityReports|Low'),
    },
  },
};
</script>

<template>
  <div
    v-gl-resize-observer="updateGridDimensions"
    class="gl-grid gl-h-full gl-gap-1"
    :style="gridStyle"
  >
    <div
      v-for="riskScore in riskScores"
      :key="riskScore.project.id"
      class="gl-flex gl-items-center gl-justify-center"
      :class="getTileBgClass(riskScore.rating)"
      data-testid="risk-score-tile"
    >
      <button
        :id="`risk-score-by-project-${riskScore.project.id}`"
        :aria-label="getAriaLabel(riskScore)"
        class="gl-m-0 gl-cursor-default gl-border-none gl-bg-transparent gl-p-0"
        :class="getTileTextClass(riskScore.rating)"
        type="button"
      >
        {{ riskScore.score }}
      </button>
      <gl-popover
        :target="`risk-score-by-project-${riskScore.project.id}`"
        container="viewport"
        :css-classes="['gl-min-w-20', 'gl-max-w-34']"
      >
        <template #title>
          <div class="gl-flex gl-w-full gl-justify-between gl-gap-6">
            <gl-link
              :href="getVulnerabilityReportUrl(riskScore.project)"
              target="_blank"
              class="gl-flex-shrink gl-truncate"
              >{{ riskScore.project.name }}</gl-link
            >
            <div class="gl-text-nowrap">{{ riskScore.score }}</div>
          </div></template
        >
        <span>{{ getRiskRatingLabel(riskScore.rating) }}</span>
      </gl-popover>
    </div>
  </div>
</template>
