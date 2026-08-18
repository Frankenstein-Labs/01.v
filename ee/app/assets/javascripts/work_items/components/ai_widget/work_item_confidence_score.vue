<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import ConfidenceBar from './confidence_bar.vue';
import {
  PLAN_CONFIDENCE_LEVELS,
  CONFIDENCE_SCORE_MEDIUM_THRESHOLD,
  CONFIDENCE_SCORE_HIGH_THRESHOLD,
} from './constants';

export default {
  name: 'WorkItemConfidenceScore',
  components: {
    ConfidenceBar,
    GlLink,
    GlSprintf,
    HelpPopover,
  },
  props: {
    score: {
      type: Number,
      required: false,
      default: null,
    },
  },
  computed: {
    // A missing score means something went wrong upstream, which we treat as
    // the lowest possible confidence (0) per product requirements.
    normalizedScore() {
      return this.score ?? 0;
    },
    confidenceLevel() {
      if (this.normalizedScore < CONFIDENCE_SCORE_MEDIUM_THRESHOLD)
        return PLAN_CONFIDENCE_LEVELS.LOW;
      if (this.normalizedScore < CONFIDENCE_SCORE_HIGH_THRESHOLD)
        return PLAN_CONFIDENCE_LEVELS.MEDIUM;
      return PLAN_CONFIDENCE_LEVELS.HIGH;
    },
    confidenceLevelText() {
      return this.$options.confidenceLevelText[this.confidenceLevel.value];
    },
    ariaLabel() {
      return sprintf(s__('AgentPlan|Confidence: %{level}'), {
        level: this.confidenceLevelText,
      });
    },
    // The raw score is a 0-1 decimal. We surface it as a whole number out of 100
    // because that is more familiar to users than a fraction.
    scoreOutOf100() {
      return Math.round(this.normalizedScore * 100);
    },
    scoreText() {
      return sprintf(s__('AgentPlan|Score: %{score} / 100'), {
        score: this.scoreOutOf100,
      });
    },
  },
  confidenceLevelText: {
    [PLAN_CONFIDENCE_LEVELS.LOW.value]: s__('AgentPlan|Low'),
    [PLAN_CONFIDENCE_LEVELS.MEDIUM.value]: s__('AgentPlan|Medium'),
    [PLAN_CONFIDENCE_LEVELS.HIGH.value]: s__('AgentPlan|High'),
  },
  popoverTitle: s__('AgentPlan|What is the confidence score?'),
  confidenceHelpPath: helpPagePath('user/work_items/workplan.md', { anchor: 'confidence-score' }),
  helpPopoverOptions: {
    content: s__(
      'AgentPlan|Shows how ready this work item is for an agent to run. To raise the score, add more detail to the work item description and to the workplan steps. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-2 gl-text-sm">
    <div
      class="gl-flex gl-items-end gl-gap-2 gl-text-xs gl-font-semibold gl-uppercase gl-tracking-widest gl-text-control-placeholder"
    >
      {{ s__('AgentPlan|Confidence') }}
      <help-popover
        :options="$options.helpPopoverOptions"
        icon="information-o"
        :aria-label="$options.popoverTitle"
      >
        <template #title>
          <div>
            <span
              class="gl-mb-2 gl-block gl-text-sm gl-font-normal gl-text-subtle"
              data-testid="confidence-score-value"
              >{{ scoreText }}
            </span>
            <span>{{ $options.popoverTitle }}</span>
          </div>
        </template>
        <gl-sprintf :message="$options.helpPopoverOptions.content">
          <template #link="{ content }">
            <gl-link :href="$options.confidenceHelpPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </help-popover>
    </div>

    <div class="gl-flex gl-items-center gl-gap-3" role="img" :aria-label="ariaLabel">
      <span>{{ confidenceLevelText }}</span>
      <confidence-bar :confidence-level="confidenceLevel" />
    </div>
  </div>
</template>
