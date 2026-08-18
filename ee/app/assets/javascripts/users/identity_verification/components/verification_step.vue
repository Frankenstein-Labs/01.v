<script>
import { GlIcon } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'VerificationStep',
  components: { GlIcon },
  props: {
    title: {
      type: String,
      required: true,
    },
    completed: {
      type: Boolean,
      required: true,
    },
    isActive: {
      type: Boolean,
      required: true,
    },
    totalSteps: {
      type: Number,
      required: false,
      default: 0,
    },
    stepIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    subhead: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    stepHelpText() {
      if (this.totalSteps > 1) {
        return sprintf(s__('IdentityVerification|Step %{stepIndex} of %{totalSteps}'), {
          stepIndex: this.stepIndex + 1,
          totalSteps: this.totalSteps,
        });
      }
      return '';
    },
  },
  i18n: {
    completed: __('Completed'),
  },
};
</script>
<template>
  <div class="gl-border gl-mt-6 gl-rounded-lg gl-p-5">
    <div class="gl-flex gl-justify-between">
      <h3 class="gl-m-0 gl-text-lg">{{ title }}</h3>
      <span v-if="completed" class="gl-text-subtle">
        <gl-icon name="check" />
        <span>{{ $options.i18n.completed }}</span>
      </span>
      <span v-else class="gl-text-subtle">{{ stepHelpText }}</span>
    </div>

    <p v-if="!completed && subhead" class="gl-m-0 gl-text-subtle" data-testid="subhead">
      {{ subhead }}
    </p>

    <slot v-if="isActive"></slot>
  </div>
</template>
