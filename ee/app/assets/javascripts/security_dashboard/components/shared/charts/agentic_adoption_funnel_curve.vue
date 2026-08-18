<script>
export default {
  name: 'AgenticAdoptionFunnelCurve',
  props: {
    /** Ratio (0–1) where the curve starts on the left. */
    startRatio: {
      type: Number,
      required: false,
      default: 1,
    },
    /** Ratio (0–1) where the curve ends on the right. Defaults to `startRatio`. */
    endRatio: {
      type: Number,
      required: false,
      default: null,
    },
  },
  computed: {
    /**
     * Builds the SVG paths for a curve that drops from `startRatio` (left) to
     * `endRatio` (right) within a normalized 1×1 viewBox. Ratios map to y axis
     * `1 - ratio` (ratio 1 = top, 0 = bottom).
     */
    decorationPaths() {
      const clamp = (value) => Math.min(1, Math.max(0, value));
      const startY = 1 - clamp(this.startRatio);
      const endY = 1 - clamp(this.endRatio ?? this.startRatio);
      const curve = `M0,${startY} C0.5,${startY} 0.5,${endY} 1,${endY}`;

      return {
        line: curve,
        area: `${curve} L1,1 L0,1 Z`,
      };
    },
  },
};
</script>

<template>
  <div class="gl-pointer-events-none gl-absolute gl-inset-0 gl-flex gl-flex-col" aria-hidden="true">
    <div class="gl-shrink-0 gl-basis-13" data-testid="funnel-curve-top-spacer"></div>
    <svg
      class="gl-min-h-0 gl-w-full gl-grow gl-basis-0 gl-overflow-visible"
      preserveAspectRatio="none"
      viewBox="0 0 1 1"
      data-testid="funnel-empty-state-chart"
    >
      <path :d="decorationPaths.area" style="fill: var(--gl-background-color-strong)" />
      <path
        :d="decorationPaths.line"
        vector-effect="non-scaling-stroke"
        stroke-linecap="round"
        style="
          fill: none;
          stroke: var(--gl-border-color-strong);
          stroke-width: 2;
          stroke-dasharray: 2 3;
        "
      />
    </svg>
  </div>
</template>
