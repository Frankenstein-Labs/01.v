<script>
import { GlButton, GlCollapse, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'CollapsibleText',
  components: {
    GlButton,
    GlCollapse,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    text: {
      type: String,
      required: false,
      default: '',
    },
    threshold: {
      type: Number,
      required: false,
      default: 80,
    },
  },
  data() {
    return {
      visible: false,
    };
  },
  computed: {
    lines() {
      return this.text.trim().split('\n');
    },
    hasHiddenLines() {
      return this.lines.slice(1).some((line) => line.trim() !== '');
    },
    // Collapsing to a single line would otherwise run every paragraph together,
    // so show the first line only and signal the rest with an ellipsis.
    collapsedText() {
      const [firstLine] = this.lines;

      return this.hasHiddenLines ? `${firstLine}…` : firstLine;
    },
    isLong() {
      return this.text.length > this.threshold || this.hasHiddenLines;
    },
    toggleLabel() {
      return this.visible ? this.$options.i18n.showLess : this.$options.i18n.showMore;
    },
    toggleIcon() {
      return this.visible ? 'chevron-down' : 'chevron-right';
    },
  },
  methods: {
    toggle() {
      this.visible = !this.visible;
    },
  },
  i18n: {
    showMore: s__('AgentArtifacts|Show more'),
    showLess: s__('AgentArtifacts|Show less'),
  },
};
</script>

<template>
  <div>
    <span v-if="!isLong" class="gl-whitespace-pre-wrap gl-break-words">{{ text }}</span>
    <div v-else class="gl-flex gl-items-start gl-gap-3">
      <!-- gl-min-w-0 lets the flex item shrink below its content width, without
      which gl-truncate has nothing to truncate against. -->
      <div class="gl-min-w-0 gl-grow">
        <span v-if="!visible" class="gl-block gl-truncate" data-testid="collapsible-text-preview">{{
          collapsedText
        }}</span>
        <gl-collapse :visible="visible">
          <span
            class="gl-block gl-whitespace-pre-wrap gl-break-words"
            data-testid="collapsible-text-full"
            >{{ text }}</span
          >
        </gl-collapse>
      </div>
      <gl-button
        v-gl-tooltip
        category="tertiary"
        size="small"
        :icon="toggleIcon"
        :aria-label="toggleLabel"
        :title="toggleLabel"
        :aria-expanded="visible.toString()"
        data-testid="collapsible-text-toggle"
        @click="toggle"
      />
    </div>
  </div>
</template>
