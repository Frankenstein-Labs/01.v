<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import AgenticAdoptionFunnelCurve from './agentic_adoption_funnel_curve.vue';

export default {
  name: 'AgenticAdoptionFunnelEmptyState',
  components: {
    GlButton,
    GlIcon,
    AgenticAdoptionFunnelCurve,
  },
  inject: {
    manageDuoSettingsPath: {
      default: '',
    },
  },
  props: {
    icon: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    /**
     * Whether the current user can enable the feature. When true, an "Enable"
     * button linking to the Duo settings page is rendered. When false, the
     * button is hidden and `disabledDescription` is shown instead.
     */
    canEnable: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Message shown when the feature cannot be enabled by the current user
     * (i.e. when `canEnable` is false).
     */
    disabledDescription: {
      type: String,
      required: true,
    },
    /**
     * Ratio (0–1, relative to the chart's y-axis max) where the decorative
     * funnel curve starts on the left. Set so the dashed line begins
     * where the real chart's line ends, reading as one continuous funnel.
     */
    startRatio: {
      type: Number,
      required: false,
      default: 1,
    },
    /**
     * Ratio (0–1) where the decorative curve flattens out on the right. Defaults
     * to `startRatio`, producing a straight horizontal line.
     */
    endRatio: {
      type: Number,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <div
    class="gl-relative gl-isolate gl-flex gl-h-full gl-flex-col gl-overflow-hidden gl-rounded-t-base gl-border-2 gl-border-dashed gl-border-subtle gl-bg-subtle gl-p-4"
    data-testid="funnel-empty-state"
  >
    <agentic-adoption-funnel-curve :start-ratio="startRatio" :end-ratio="endRatio" />

    <div class="gl-relative gl-z-1 gl-flex gl-h-full gl-flex-col">
      <div class="gl-flex gl-items-center gl-gap-3">
        <div
          class="gl-flex gl-items-center gl-justify-center gl-rounded-full gl-bg-strong gl-p-3"
          data-testid="funnel-empty-state-icon"
        >
          <gl-icon :name="icon" :size="16" />
        </div>
        <p class="gl-heading-5 gl-my-0" data-testid="funnel-empty-state-heading">{{ title }}</p>
      </div>

      <template v-if="canEnable">
        <p class="gl-my-3 gl-text-sm gl-text-subtle @md/panel:gl-text-base">{{ description }}</p>
        <gl-button
          :href="manageDuoSettingsPath"
          variant="confirm"
          category="primary"
          size="small"
          class="gl-self-start"
          data-testid="funnel-empty-state-enable-button"
        >
          {{ s__('SecurityReports|Enable') }}
        </gl-button>
      </template>

      <p
        v-else
        class="gl-mb-0 gl-mt-4 gl-flex gl-items-start gl-gap-2 gl-text-subtle"
        data-testid="funnel-empty-state-disabled-description"
      >
        <span class="gl-flex gl-h-6 gl-shrink-0 gl-items-center">
          <gl-icon name="tanuki-ai" :size="16" />
        </span>
        {{ disabledDescription }}
      </p>
    </div>
  </div>
</template>
