<script>
import { GlButton } from '@gitlab/ui';

export default {
  components: {
    GlButton,
  },
  props: {
    ruleKey: {
      type: String,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    addButtonText: {
      type: String,
      required: true,
    },
    environment: {
      type: Object,
      required: true,
    },
  },
  emits: ['add-rule'],
  computed: {
    rules() {
      return this.environment[this.ruleKey] || [];
    },
  },
  methods: {
    addRule(environment) {
      this.$emit('add-rule', { environment, ruleKey: this.ruleKey });
    },
  },
};
</script>
<template>
  <div>
    <slot name="table"></slot>

    <div v-if="!rules.length" data-testid="empty-state" class="gl-bg-default gl-p-5">
      <slot name="empty-state"></slot>
    </div>

    <div class="gl-border-t gl-flex gl-items-center gl-p-5">
      <gl-button
        category="secondary"
        variant="confirm"
        class="gl-ml-auto"
        :loading="loading"
        @click="addRule(environment)"
      >
        {{ addButtonText }}
      </gl-button>
    </div>
  </div>
</template>
