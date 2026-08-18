<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import CodeBlockDeprecatedStrategyBadge from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_deprecated_strategy_badge.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  CUSTOM_STRATEGY_OPTIONS,
  CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS,
  CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED_LISTBOX_ITEMS,
  DEPRECATED_INJECT,
  INJECT,
  SCHEDULE,
  SCHEDULE_TEXT,
} from '../constants';
import { validateStrategyValues } from './utils';

export default {
  name: 'CodeBlockStrategySelector',
  components: {
    CodeBlockDeprecatedStrategyBadge,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    strategy: {
      type: String,
      required: false,
      default: INJECT,
      validator: validateStrategyValues,
    },
  },
  emits: ['select'],
  computed: {
    showDeprecatedInjectStrategy() {
      return this.strategy === DEPRECATED_INJECT;
    },
    items() {
      const items = this.showDeprecatedInjectStrategy
        ? CUSTOM_STRATEGY_OPTIONS_WITH_DEPRECATED_LISTBOX_ITEMS
        : CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS;

      if (this.glFeatures.scheduledPipelineExecutionPolicies) {
        return [...items, { value: SCHEDULE, text: SCHEDULE_TEXT }];
      }

      return items;
    },
    toggleText() {
      return CUSTOM_STRATEGY_OPTIONS[this.strategy];
    },
  },
  methods: {
    showDeprecatedBadge(value) {
      return value === DEPRECATED_INJECT;
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    id="strategy-selector-dropdown"
    label-for="file-path"
    fluid-width
    data-testid="strategy-selector-dropdown"
    :items="items"
    :toggle-text="toggleText"
    :selected="strategy"
    @select="$emit('select', $event)"
  >
    <template #list-item="{ item: { value, text } }">
      <div class="gl-flex gl-items-center">
        <div>{{ text }}</div>
        <code-block-deprecated-strategy-badge v-if="showDeprecatedBadge(value)" class="gl-ml-2" />
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
