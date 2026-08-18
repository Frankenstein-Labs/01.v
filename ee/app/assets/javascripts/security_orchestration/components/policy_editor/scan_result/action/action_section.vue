<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { ACTION_AND_LABEL } from '../../constants';
import ApproverAction from './approver_action.vue';

export default {
  ACTION_AND_LABEL,
  name: 'ActionSection',
  components: {
    GlAlert,
    GlButton,
    ApproverAction,
  },
  props: {
    actionIndex: {
      type: Number,
      required: true,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    initAction: {
      type: Object,
      required: true,
    },
    isWarnType: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['changed', 'error', 'remove'],
  computed: {
    isFirstAction() {
      return this.actionIndex === 0;
    },
    actionErrors() {
      return this.errors.filter((error) => {
        if ('index' in error) {
          return error.index === this.actionIndex;
        }

        return error;
      });
    },
  },
  methods: {
    remove() {
      this.$emit('remove');
    },
    errorKey(error) {
      return error.index;
    },
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-mb-4 gl-ml-5 gl-text-subtle"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>

    <gl-alert
      v-for="error in actionErrors"
      :key="errorKey(error)"
      class="gl-w-full"
      :dismissible="false"
      :title="error.title"
      variant="danger"
    >
      {{ error.message }}
    </gl-alert>

    <div class="gl-flex gl-w-full">
      <div class="gl-flex-1">
        <approver-action
          :action-index="actionIndex"
          :init-action="initAction"
          :is-warn-type="isWarnType"
          :errors="errors"
          @error="$emit('error')"
          @changed="$emit('changed', $event)"
        />
      </div>
      <div class="security-policies-bg-subtle">
        <gl-button
          icon="remove"
          category="tertiary"
          :aria-label="__('Remove')"
          data-testid="remove-action"
          @click="remove"
        />
      </div>
    </div>
  </div>
</template>
