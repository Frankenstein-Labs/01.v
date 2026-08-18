<script>
export default {
  name: 'ActivityConnectorSvg',
  props: {
    targets: {
      type: Array,
      required: true,
      validator(v) {
        return v.every((target) => target instanceof HTMLElement);
      },
    },
  },
  data() {
    return {
      svgRect: {},
    };
  },
  computed: {
    startCoordinate() {
      return this.computeCoordinates(this.targets[0]);
    },
    endCoordinate() {
      return this.computeCoordinates(this.targets[this.targets.length - 1]);
    },
  },
  mounted() {
    window.addEventListener('resize', this.updateSvgRect);
    this.updateSvgRect();
  },
  methods: {
    computeCoordinates(target) {
      if (!target || (!this.svgRect.left && this.svgRect.left !== 0)) return { x: 0, y: 0 };
      const targetRect = target.getBoundingClientRect();
      return {
        x: targetRect.left + targetRect.width / 2 - this.svgRect.left,
        y: targetRect.top - this.svgRect.top,
      };
    },
    updateSvgRect() {
      if (!this.$refs.svg) return;
      // Use setTimeout to ensure the DOM has updated
      setTimeout(() => {
        this.svgRect = this.$refs.svg.getBoundingClientRect();
      }, 0);
    },
  },
};
</script>

<template>
  <svg ref="svg" aria-hidden="true" class="pointer-events-none gl-absolute gl-z-0 gl-h-full">
    <line
      :x1="startCoordinate.x"
      :y1="startCoordinate.y"
      :x2="endCoordinate.x"
      :y2="endCoordinate.y"
      stroke="var(--gl-background-color-strong)"
      stroke-width="1"
    />
  </svg>
</template>
