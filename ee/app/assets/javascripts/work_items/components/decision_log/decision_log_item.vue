<script>
import { GlBadge, GlIcon } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { s__, sprintf } from '~/locale';
import {
  DECIDED_DECISION_STATUSES,
  DECISION_STATUS_LABELS,
  DECISION_STATUS_ICONS,
  DECISION_STATUS_VARIANTS,
  DECISION_CATEGORY_LABELS,
  DECISION_CATEGORY_VARIANTS,
} from './constants';

export default {
  name: 'DecisionLogItem',
  components: {
    GlBadge,
    GlIcon,
    TimeAgoTooltip,
  },
  props: {
    decision: {
      type: Object,
      required: true,
    },
    /** Short human-facing reference such as `DL-002`, assigned by the list. */
    reference: {
      type: String,
      required: true,
    },
  },
  computed: {
    categoryLabel() {
      return DECISION_CATEGORY_LABELS[this.decision.category] ?? this.decision.category;
    },
    categoryVariant() {
      return DECISION_CATEGORY_VARIANTS[this.decision.category] ?? 'neutral';
    },
    statusLabel() {
      return DECISION_STATUS_LABELS[this.decision.status] ?? this.decision.status;
    },
    statusIcon() {
      return DECISION_STATUS_ICONS[this.decision.status] ?? 'status-neutral';
    },
    statusVariant() {
      return DECISION_STATUS_VARIANTS[this.decision.status] ?? 'neutral';
    },
    isPending() {
      return !DECIDED_DECISION_STATUSES.includes(this.decision.status);
    },
    // Pending decisions have not been decided yet, so fall back to when they were raised.
    timestamp() {
      return this.decision.decidedAt ?? this.decision.createdAt;
    },
    assigneeText() {
      if (!this.decision.assignee) return '';

      return sprintf(s__('WorkItemDecisionLog|Awaiting %{name}'), {
        name: this.decision.assignee.name,
      });
    },
    selectedOptionText() {
      if (this.isPending) return '';

      return this.decision.selectedOption?.text ?? '';
    },
  },
  i18n: {
    selected: s__('WorkItemDecisionLog|Selected'),
  },
};
</script>

<template>
  <li
    class="gl-mb-3 gl-list-none gl-rounded-base gl-border-1 gl-border-solid gl-p-4"
    :class="
      isPending
        ? 'gl-border-feedback-warning gl-bg-status-warning'
        : 'gl-border-section gl-bg-default'
    "
    data-testid="decision-log-item"
  >
    <div class="gl-flex gl-items-start gl-gap-3">
      <gl-icon
        :name="statusIcon"
        :aria-label="statusLabel"
        class="gl-mt-1 gl-shrink-0"
        data-testid="decision-status-icon"
      />

      <div class="gl-min-w-0 gl-grow">
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <span class="gl-font-bold" data-testid="decision-author">{{ decision.author.name }}</span>

          <gl-badge :variant="categoryVariant" data-testid="decision-category">
            {{ categoryLabel }}
          </gl-badge>

          <gl-badge :variant="statusVariant" data-testid="decision-status">
            {{ statusLabel }}
          </gl-badge>

          <time-ago-tooltip :time="timestamp" class="gl-text-sm gl-text-subtle" />
        </div>

        <p class="gl-mb-0 gl-mt-2" data-testid="decision-title">{{ decision.title }}</p>

        <p
          v-if="assigneeText"
          class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-subtle"
          data-testid="decision-assignee"
        >
          {{ assigneeText }}
        </p>

        <p
          v-if="selectedOptionText"
          class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-subtle"
          data-testid="decision-selected-option"
        >
          {{ $options.i18n.selected }}: {{ selectedOptionText }}
        </p>
      </div>

      <span class="gl-shrink-0 gl-text-sm gl-text-subtle" data-testid="decision-reference">
        {{ reference }}
      </span>
    </div>
  </li>
</template>
