<script>
import { GlFilteredSearchSuggestion, GlIcon, GlTruncate, GlTooltipDirective } from '@gitlab/ui';

export default {
  components: {
    GlFilteredSearchSuggestion,
    GlIcon,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    /**
     * The value of the suggestion.
     * This is passed to gl-filtered-search-suggestion and used in data test ids.
     */
    value: {
      type: [String, Number],
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    selected: {
      type: Boolean,
      required: true,
    },
    truncate: {
      type: Boolean,
      required: false,
      default: false,
    },
    tooltipText: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>
<template>
  <gl-filtered-search-suggestion :value="value">
    <div class="gl-flex gl-items-center">
      <gl-icon
        name="check"
        class="gl-mr-3 gl-shrink-0"
        :class="{ 'gl-invisible': !selected }"
        variant="subtle"
      />
      <gl-truncate v-if="truncate" position="middle" :text="text" />
      <template v-else>{{ text }}</template>
      <gl-icon
        v-if="tooltipText"
        v-gl-tooltip="{ boundary: 'viewport' }"
        data-testid="tooltip-icon"
        name="question-o"
        variant="subtle"
        class="gl-ml-3"
        :title="tooltipText"
      />
    </div>
  </gl-filtered-search-suggestion>
</template>
