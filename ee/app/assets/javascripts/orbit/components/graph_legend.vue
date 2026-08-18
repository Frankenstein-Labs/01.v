<script>
import { defineComponent } from 'vue';
import { GlButton, GlButtonGroup, GlToggle, GlTruncate } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';

const COLLAPSED_COUNT = 5;

export default defineComponent({
  name: 'GraphLegend',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlButtonGroup,
    GlToggle,
    GlTruncate,
  },
  i18n: {
    entities: s__('Orbit|Entities'),
    showLess: s__('Orbit|Show less'),
    showLabels: s__('Orbit|Show labels'),
    zoom: s__('Orbit|Zoom'),
    zoomIn: s__('Orbit|Zoom in'),
    zoomOut: s__('Orbit|Zoom out'),
  },
  props: {
    items: {
      type: Array,
      required: false,
      default: () => [],
    },
    activeTypeFilters: {
      type: Set,
      required: false,
      default: () => new Set(),
    },
    isCompact: {
      type: Boolean,
      required: false,
      default: false,
    },
    labelsVisible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['select-type', 'update-labels-visible', 'zoom-in', 'zoom-out'],
  data() {
    return {
      expanded: false,
    };
  },
  computed: {
    sortedItems() {
      return [...this.items].sort((a, b) => {
        const ca = a.count ?? 0;
        const cb = b.count ?? 0;
        if (cb !== ca) return cb - ca;
        return a.name.localeCompare(b.name);
      });
    },
    visibleItems() {
      if (!this.isCompact || this.expanded) return this.sortedItems;
      return this.sortedItems.slice(0, COLLAPSED_COUNT);
    },
    hiddenCount() {
      if (!this.isCompact || this.expanded) return 0;
      return Math.max(0, this.sortedItems.length - COLLAPSED_COUNT);
    },
    hasOverflow() {
      return this.isCompact && this.sortedItems.length > COLLAPSED_COUNT;
    },
    moreLabel() {
      return sprintf(n__('Orbit|+%{count} more', 'Orbit|+%{count} more', this.hiddenCount), {
        count: this.hiddenCount,
      });
    },
  },
  methods: {
    isActive(type) {
      return this.activeTypeFilters.size === 0 || this.activeTypeFilters.has(type);
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-min-h-0 gl-flex-col gl-gap-3">
    <div
      v-if="items.length"
      class="gl-flex gl-min-h-0 gl-flex-col gl-gap-2 gl-rounded-lg gl-bg-subtle gl-p-3"
      data-testid="graph-legend"
    >
      <span class="gl-text-sm gl-font-semibold">{{ $options.i18n.entities }}</span>
      <div class="gl-flex gl-min-h-0 gl-flex-col gl-gap-2 gl-overflow-y-auto">
        <button
          v-for="item in visibleItems"
          :key="item.type"
          type="button"
          class="gl-flex gl-items-center gl-gap-2 gl-rounded-lg gl-border-0 gl-bg-transparent gl-p-2 gl-shadow-none hover:gl-bg-strong"
          :class="isActive(item.type) ? '' : 'gl-opacity-3'"
          :aria-pressed="String(isActive(item.type))"
          data-testid="legend-item"
          @click="$emit('select-type', item.type)"
        >
          <span class="gl-flex gl-w-20 gl-min-w-0 gl-shrink-0 gl-items-center gl-gap-3">
            <span
              class="gl-inline-block gl-h-3 gl-w-3 gl-flex-shrink-0 gl-rounded-full"
              :style="{ backgroundColor: item.color }"
            ></span>
            <gl-truncate :text="item.name" class="gl-text-left gl-text-sm" with-tooltip />
          </span>
          <span class="gl-w-8 gl-shrink-0 gl-pr-1 gl-text-right">
            <span v-if="item.count > 0" class="gl-text-sm">
              {{ item.count }}
            </span>
          </span>
        </button>
        <button
          v-if="hasOverflow"
          type="button"
          class="gl-border-0 gl-bg-transparent gl-p-0 gl-text-sm gl-text-link"
          data-testid="toggle-legend-btn"
          @click="expanded = !expanded"
        >
          <template v-if="expanded">{{ $options.i18n.showLess }}</template>
          <template v-else>{{ moreLabel }}</template>
        </button>
      </div>
    </div>
    <div class="gl-flex gl-shrink-0 gl-flex-col gl-gap-2 gl-rounded-lg gl-bg-subtle gl-p-3">
      <div class="gl-flex gl-flex-1 gl-items-center gl-justify-between gl-py-2 gl-text-sm">
        <span>{{ $options.i18n.showLabels }}</span>
        <gl-toggle
          :value="labelsVisible"
          :label="$options.i18n.showLabels"
          label-position="hidden"
          data-testid="toggle-labels"
          @change="$emit('update-labels-visible', $event)"
        />
      </div>
      <div class="gl-flex gl-flex-1 gl-items-center gl-justify-between gl-py-2 gl-text-sm">
        <span>{{ $options.i18n.zoom }}</span>
        <gl-button-group>
          <gl-button
            size="small"
            icon="dash"
            :aria-label="$options.i18n.zoomOut"
            data-testid="zoom-out"
            @click="$emit('zoom-out')"
          />
          <gl-button
            size="small"
            icon="plus"
            :aria-label="$options.i18n.zoomIn"
            data-testid="zoom-in"
            @click="$emit('zoom-in')"
          />
        </gl-button-group>
      </div>
    </div>
  </div>
</template>
