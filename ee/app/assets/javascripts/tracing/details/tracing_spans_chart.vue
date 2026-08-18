<script>
import { GlButton, GlTruncate, GlIcon } from '@gitlab/ui';
import { clamp } from 'lodash-es';
import { s__ } from '~/locale';
import { formatDurationMs } from '../trace_utils';

export default {
  name: 'TracingSpansChart',
  components: {
    GlButton,
    GlTruncate,
    GlIcon,
  },
  i18n: {
    toggleChildrenSpans: s__('Tracing|Toggle child spans'),
  },
  props: {
    customClass: {
      required: false,
      type: String,
      default: null,
    },
    spans: {
      required: true,
      type: Array,
    },
    traceDurationMs: {
      required: true,
      type: Number,
    },
    depth: {
      required: false,
      type: Number,
      default: 0,
    },
    serviceToColor: {
      required: true,
      type: Object,
    },
    selectedSpanId: {
      required: false,
      type: String,
      default: null,
    },
  },
  emits: ['span-selected'],
  data() {
    return {
      expanded: this.expandedState(this.spans),
    };
  },
  computed: {
    spanDetailsStyle() {
      return {
        paddingLeft: `${this.depth * 16}px`,
      };
    },
  },
  watch: {
    spans(_, newSpans) {
      this.expanded = this.expandedState(newSpans);
    },
  },
  methods: {
    expandedState(spans) {
      return spans.map((x) => x.children.length > 0);
    },
    hasChildrenSpans(index) {
      return this.spans[index].children.length > 0;
    },
    hasError(index) {
      return this.spans[index].hasError;
    },
    toggleExpand(index) {
      if (!this.hasChildrenSpans(index)) return;
      const copy = [...this.expanded];
      copy[index] = !this.isExpanded(index);
      this.expanded = copy;
    },
    isExpanded(index) {
      return this.expanded[index];
    },
    durationBarLayout(span) {
      const computedWidth = Math.floor((100 * span.duration_ms) / this.traceDurationMs);
      const width = clamp(computedWidth, 0.5, 100);

      const computedMarginLeft = Math.floor((100 * span.start_ms) / this.traceDurationMs);
      const marginLeft = clamp(
        computedMarginLeft,
        0, // avoid negative margins. this can happen in case of skewed time between the root and child spans
        100 - width, // make sure spans do not overlow.
      );

      return {
        marginLeft,
        width,
      };
    },
    durationValueStyle(span) {
      const { marginLeft } = this.durationBarLayout(span);
      return {
        marginLeft: `${marginLeft}%`,
      };
    },
    durationBarStyle(span) {
      const { width, marginLeft } = this.durationBarLayout(span);
      return {
        width: `${width}%`,
        marginLeft: `${marginLeft}%`,
        height: '32px',
        borderRadius: '4px',
      };
    },
    durationValue(span) {
      return formatDurationMs(span.duration_ms);
    },
    onSelect({ spanId }) {
      this.$emit('span-selected', { spanId });
    },
    isSpanSelected(span) {
      return span.span_id === this.selectedSpanId;
    },
  },
};
</script>

<template>
  <div v-if="spans.length" :class="['span-tree', customClass]">
    <div
      v-for="(span, index) in spans"
      :key="span.span_id"
      :data-testid="`span-wrapper-${depth}-${index}`"
    >
      <div
        data-testid="span-inner-container"
        class="gl-border-b gl-flex gl-cursor-pointer"
        :class="{
          'gl-bg-blue-100': isSpanSelected(span),
          'hover:gl-bg-alpha-dark-8': !isSpanSelected(span),
        }"
        @click="onSelect({ spanId: span.span_id })"
      >
        <div
          data-testid="span-details"
          class="gl-border-r gl-flex gl-w-3/10 gl-min-w-20 gl-flex-row gl-p-3"
          :style="spanDetailsStyle"
        >
          <div>
            <gl-button
              :aria-label="$options.i18n.toggleChildrenSpans"
              class="gl-mr-1"
              :class="{ 'gl-invisible': !hasChildrenSpans(index) }"
              :icon="`chevron-${isExpanded(index) ? 'down' : 'right'}`"
              category="tertiary"
              size="small"
              @click.stop="toggleExpand(index)"
            />
            <gl-icon
              v-if="hasError(index)"
              data-testid="span-details-error-icon"
              name="status-alert"
              class="gl-mr-3 gl-text-danger"
            />
          </div>

          <div class="gl-flex gl-flex-col gl-truncate">
            <gl-truncate class="gl-font-bold gl-text-default" :text="span.operation" with-tooltip />
            <gl-truncate class="gl-text-subtle" :text="span.service" with-tooltip />
          </div>
        </div>

        <div class="gl-flex gl-grow gl-flex-col gl-justify-center gl-px-4 gl-py-3">
          <div
            data-testid="span-duration-bar"
            :style="durationBarStyle(span)"
            :class="serviceToColor[span.service]"
          ></div>
          <span
            data-testid="span-duration-value"
            :style="durationValueStyle(span)"
            class="gl-text-subtle"
            >{{ durationValue(span) }}</span
          >
        </div>
      </div>

      <tracing-spans-chart
        v-show="isExpanded(index)"
        :spans="span.children"
        :depth="depth + 1"
        :trace-duration-ms="traceDurationMs"
        :service-to-color="serviceToColor"
        :selected-span-id="selectedSpanId"
        @span-selected="onSelect"
      />
    </div>
  </div>
</template>
