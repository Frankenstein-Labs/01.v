<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';

export default {
  name: 'CatalogGroup',
  components: { GlButton, GlIcon },
  directives: { GlTooltip: GlTooltipDirective },
  props: {
    group: {
      type: Object,
      required: true,
    },
    selectedIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    optionTestid: {
      type: String,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return { highlightedItem: null };
  },
  methods: {
    isSelected({ id }) {
      return this.selectedIds.includes(id);
    },
    ariaPressed(item) {
      return String(this.isSelected(item));
    },
    showsInfo(item) {
      return this.highlightedItem === item.id && Boolean(item.description);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-2">
    <p class="gl-mb-0 gl-px-2 gl-py-1 gl-text-sm gl-font-semibold gl-text-subtle">
      {{ group.label }}
    </p>
    <gl-button
      v-for="item in group.items"
      :key="item.id"
      v-gl-tooltip
      :title="item.description"
      block
      :aria-pressed="ariaPressed(item)"
      :data-testid="optionTestid"
      class="!gl-rounded-lg"
      button-text-classes="gl-flex gl-w-full gl-min-w-0 gl-items-center gl-gap-3 gl-text-left"
      @click="$emit('select', item.id)"
      @mouseenter="highlightedItem = item.id"
      @mouseleave="highlightedItem = null"
      @focusin="highlightedItem = item.id"
      @focusout="highlightedItem = null"
    >
      <span
        class="gl-flex gl-h-6 gl-w-6 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-base gl-text-subtle"
      >
        <gl-icon :name="item.icon" :size="14" />
      </span>
      <span class="gl-min-w-0 gl-flex-1 gl-truncate gl-text-sm">{{ item.label }}</span>
      <gl-icon
        v-if="showsInfo(item)"
        name="information-o"
        :size="14"
        class="gl-flex-shrink-0 gl-text-subtle"
      />
      <gl-icon
        v-else-if="isSelected(item)"
        name="check-circle-filled"
        :size="14"
        class="gl-flex-shrink-0 gl-text-success"
      />
    </gl-button>
  </div>
</template>
