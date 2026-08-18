<script>
import { cloneDeep } from 'lodash-es';
import { GlCard, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { STRATEGIES, STRATEGIES_RULE_MAP } from '../lib';

export default {
  name: 'StrategySelector',
  STRATEGIES,
  components: {
    GlCard,
    GlFormRadio,
    GlFormRadioGroup,
  },
  props: {
    strategy: {
      type: String,
      required: true,
    },
  },
  emits: ['changed'],
  methods: {
    handleSelection(strategy) {
      // Need to deep clone strategy to avoid mutation issues if the user customizes the rule
      this.$emit('changed', { strategy, rules: cloneDeep(STRATEGIES_RULE_MAP[strategy]) });
    },
  },
};
</script>

<template>
  <div>
    <h5>{{ s__('SecurityOrchestration|Scan execution strategy') }}</h5>
    <gl-form-radio-group :checked="strategy" @change="handleSelection">
      <gl-card
        v-for="selected in $options.STRATEGIES"
        :key="selected.key"
        :data-testid="selected.key"
        class="gl-mb-5 gl-bg-default"
      >
        <gl-form-radio
          :value="selected.key"
          class="gl-mt-3"
          :data-testid="`${selected.key}-radio-button`"
        >
          <h6 class="gl-mt-0">{{ selected.header }}</h6>
          <template #help>
            {{ selected.description }}
          </template>
        </gl-form-radio>
      </gl-card>
    </gl-form-radio-group>
  </div>
</template>
