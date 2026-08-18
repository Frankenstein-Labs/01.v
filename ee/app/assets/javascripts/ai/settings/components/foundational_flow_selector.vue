<script>
import { GlFormCheckbox } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  name: 'FoundationalFlowSelector',
  components: {
    GlFormCheckbox,
  },
  directives: {
    SafeHtml,
  },
  inject: ['availableFoundationalFlows'],
  props: {
    value: {
      type: Array,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  methods: {
    isFlowSelected(reference) {
      return this.value.includes(reference);
    },
    toggleFlow(reference, checked) {
      const newSelection = checked
        ? [...this.value, reference]
        : this.value.filter((ref) => ref !== reference);

      this.$emit('input', newSelection);
    },
  },
};
</script>

<template>
  <div class="gl-ml-6 gl-mt-3">
    <div v-for="flow in availableFoundationalFlows" :key="flow.reference">
      <gl-form-checkbox
        :checked="isFlowSelected(flow.reference)"
        :disabled="disabled"
        data-testid="foundational-flow-checkbox"
        @input="toggleFlow(flow.reference, $event)"
      >
        <div>
          {{ flow.name }}
          <div
            v-if="flow.descriptionHtml"
            v-safe-html="flow.descriptionHtml"
            class="md gl-text-sm gl-text-subtle"
          ></div>
          <div v-else class="gl-text-sm gl-text-subtle">{{ flow.description }}</div>
        </div>
      </gl-form-checkbox>
      <slot name="after-flow" :reference="flow.reference"></slot>
    </div>
  </div>
</template>
