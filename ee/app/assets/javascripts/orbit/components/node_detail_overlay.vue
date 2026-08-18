<script>
import { defineComponent } from 'vue';
import { s__ } from '~/locale';
import { ENTITY_TYPE_COLORS, ENTITY_TYPE_NAMES, DEFAULT_ENTITY_COLOR } from '../constants';

const i18n = {
  expandHint: s__('Orbit|Double-click to explore connections'),
};

const TOP_TYPES_LIMIT = 5;

export default defineComponent({
  name: 'NodeDetailOverlay',
  compatConfig: { MODE: 3 },
  props: {
    node: {
      type: Object,
      required: false,
      default: null,
    },
    position: {
      type: Object,
      required: false,
      default: null,
    },
    entityColors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    entityNames: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    allNodes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  i18n,
  computed: {
    overlayStyle() {
      return {
        left: `${this.position.x + 16}px`,
        top: `${this.position.y - 10}px`,
      };
    },
    typeColor() {
      const key = (this.node.type || 'default').toLowerCase();
      return this.entityColors[key] || ENTITY_TYPE_COLORS[key];
    },
    typeLabel() {
      const key = (this.node.type || '').toLowerCase();
      return this.entityNames[key] || ENTITY_TYPE_NAMES[key] || this.node.type || '';
    },
    connectionSummary() {
      if (!this.node) return [];

      const typeCounts = [...(this.node.connections ?? [])].reduce((acc, idx) => {
        const neighbor = this.allNodes[idx];
        if (neighbor) {
          const t = (neighbor.type || 'unknown').toLowerCase();
          acc[t] = (acc[t] || 0) + 1;
        }
        return acc;
      }, {});

      return Object.entries(typeCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, TOP_TYPES_LIMIT)
        .map(([type, count]) => ({
          type,
          count,
          color: this.entityColors[type] || ENTITY_TYPE_COLORS[type] || DEFAULT_ENTITY_COLOR,
          label: this.entityNames[type] || ENTITY_TYPE_NAMES[type] || type,
        }));
    },
  },
});
</script>

<template>
  <div
    v-if="node && position"
    class="orbit-frosted-panel node-detail-overlay gl-z-10 gl-pointer-events-none gl-absolute gl-max-w-80 gl-rounded-lg gl-p-3"
    :style="overlayStyle"
    data-testid="node-detail-overlay"
  >
    <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-font-semibold" data-testid="overlay-node-label">
      {{ node.label || node.id }}
    </p>
    <p class="node-detail-type-label gl-mb-2 gl-mt-0" :style="{ color: typeColor }">
      {{ typeLabel }}
    </p>

    <!-- Connection breakdown by type -->
    <div v-if="connectionSummary.length > 0" class="gl-mb-1">
      <div
        v-for="conn in connectionSummary"
        :key="conn.type"
        class="gl-leading-relaxed gl-flex gl-items-center gl-gap-2 gl-text-xs"
      >
        <span
          class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
          :style="{ backgroundColor: conn.color }"
        ></span>
        <span class="gl-text-subtle">{{ conn.count }}</span>
        <span>{{ conn.label }}</span>
      </div>
    </div>

    <p
      v-if="node.connections && node.connections.size"
      class="gl-mb-0 gl-mt-1 gl-text-xs gl-text-subtle"
    >
      {{ $options.i18n.expandHint }}
    </p>
  </div>
</template>
