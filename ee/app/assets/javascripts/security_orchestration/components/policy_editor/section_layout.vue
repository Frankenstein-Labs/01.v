<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';

export default {
  name: 'SectionLayoutEE',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    contentClasses: {
      type: String,
      required: false,
      default: '',
    },
    ruleLabel: {
      type: String,
      required: false,
      default: '',
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    disableRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    disableRemoveButtonTitle: {
      type: String,
      required: false,
      default: '',
    },
    labelClasses: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['remove'],
  computed: {
    contentClass() {
      return `gl-grow gl-w-full gl-flex gl-gap-3 gl-items-center gl-flex-wrap ${this.contentClasses}`;
    },
    labelClass() {
      return `gl-w-6 gl-font-normal gl-mb-0 gl-text-lg ${this.labelClasses}`;
    },
    showLabel() {
      return Boolean(this.ruleLabel);
    },
  },
};
</script>

<template>
  <div class="security-policies-bg-subtle gl-flex gl-gap-3 gl-rounded-base gl-p-5">
    <div v-if="showLabel" class="gl-min-w-10 @md/panel:gl-min-w-7">
      <label data-testid="base-label" for="content" :class="labelClass">
        {{ ruleLabel }}
      </label>
    </div>

    <div data-testid="content" :class="contentClass">
      <slot name="selector"> </slot>
      <slot name="content"></slot>
    </div>

    <div
      v-if="showRemoveButton"
      v-gl-tooltip.hover
      class="gl-min-w-7"
      :title="disableRemoveButtonTitle"
    >
      <gl-button
        :disabled="disableRemoveButton"
        :class="{ '!gl-border-0': disableRemoveButton }"
        icon="remove"
        category="tertiary"
        :aria-label="__('Remove')"
        data-testid="remove-rule"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>
