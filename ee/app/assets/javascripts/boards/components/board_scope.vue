<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import AssigneeSelect from './assignee_select.vue';
import BoardLabelsSelect from './labels_select.vue';
import BoardIterationSelect from './iteration_select.vue';
import BoardMilestoneSelect from './milestone_select.vue';
import BoardWeightSelect from './weight_select.vue';

export default {
  name: 'BoardScope',
  components: {
    GlButton,
    AssigneeSelect,
    BoardLabelsSelect,
    BoardIterationSelect,
    BoardMilestoneSelect,
    BoardWeightSelect,
  },
  inject: ['isIssueBoard'],
  props: {
    collapseScope: {
      type: Boolean,
      required: true,
    },
    canAdminBoard: {
      type: Boolean,
      required: true,
    },
    board: {
      type: Object,
      required: true,
    },
    weights: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['set-assignee', 'set-board-labels', 'set-iteration', 'set-milestone', 'set-weight'],

  data() {
    return {
      expanded: false,
    };
  },

  computed: {
    expandButtonText() {
      return this.expanded ? __('Collapse') : __('Expand');
    },
    scopeText() {
      return this.isIssueBoard
        ? __('Board scope affects which issues are displayed for anyone who visits this board')
        : __('Board scope affects which epics are displayed for anyone who visits this board');
    },
  },

  methods: {
    handleLabelClick(labels) {
      this.$emit('set-board-labels', labels);
    },
  },
};
</script>

<template>
  <div data-testid="board-scope-modal">
    <div v-if="canAdminBoard" class="media">
      <label class="label-bold media-body gl-text-lg">{{ __('Scope') }}</label>
      <gl-button v-if="collapseScope" @click="expanded = !expanded">
        {{ expandButtonText }}
      </gl-button>
    </div>
    <div v-else class="gl-mb-2 gl-text-lg gl-font-bold">{{ __('Scope') }}</div>
    <p class="gl-mb-3 gl-text-subtle">
      {{ scopeText }}
    </p>
    <div v-if="!collapseScope || expanded">
      <board-milestone-select
        v-if="isIssueBoard"
        :board="board"
        :can-edit="canAdminBoard"
        @set-milestone="$emit('set-milestone', $event)"
      />

      <board-iteration-select
        v-if="isIssueBoard"
        :board="board"
        :can-edit="canAdminBoard"
        @set-iteration="$emit('set-iteration', $event)"
      />

      <board-labels-select
        :board="board"
        :can-edit="canAdminBoard"
        @set-labels="handleLabelClick"
      />

      <assignee-select
        v-if="isIssueBoard"
        :board="board"
        :can-edit="canAdminBoard"
        @set-assignee="$emit('set-assignee', $event)"
      />

      <board-weight-select
        v-if="isIssueBoard"
        :board="board"
        :weights="weights"
        :can-edit="canAdminBoard"
        @set-weight="$emit('set-weight', $event)"
      />
    </div>
  </div>
</template>
