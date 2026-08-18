<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'ChangeLifecycleStepper',
  components: {
    GlButton,
  },
  props: {
    steps: {
      type: Array,
      required: true,
      validator: (steps) => {
        return steps.every((step) => step.label);
      },
    },
    initialStep: {
      type: Number,
      required: false,
      default: 0,
    },
    showBackButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showNextButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showFinishButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showCancelButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    isValidStep: {
      type: Boolean,
      required: false,
      default: true,
    },
    isUpdating: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel', 'finish', 'reset', 'step-change', 'validate-step'],
  data() {
    return {
      currentStep: this.initialStep,
      canProceed: true,
    };
  },
  watch: {
    initialStep: {
      immediate: true,
      handler(newVal) {
        this.currentStep = newVal;
      },
    },
    isValidStep: {
      immediate: true,
      handler(newVal) {
        this.canProceed = newVal;
      },
    },
  },
  methods: {
    async nextStep() {
      if (this.currentStep < this.steps.length - 1) {
        this.validateStep(this.currentStep);
        await this.$nextTick();
        if (this.canProceed) {
          this.currentStep += 1;
          this.$emit('step-change', {
            currentStep: this.currentStep,
            direction: 'next',
            step: this.steps[this.currentStep],
          });
        }
      }
    },
    previousStep() {
      if (this.currentStep > 0) {
        this.currentStep -= 1;
        this.$emit('step-change', {
          currentStep: this.currentStep,
          direction: 'previous',
          step: this.steps[this.currentStep],
        });
      }
    },
    validateStep(stepIndex) {
      this.$emit('validate-step', {
        stepIndex,
        step: this.steps[stepIndex],
      });
    },
    async finish() {
      this.validateStep(this.currentStep);
      await this.$nextTick();
      if (this.canProceed) {
        this.$emit('finish', {
          completedSteps: this.steps,
          currentStep: this.currentStep,
        });
      }
    },
    // eslint-disable-next-line vue/no-unused-properties -- will be used in next MR
    reset() {
      this.currentStep = this.initialStep;
      this.$emit('reset');
    },
    cancel() {
      this.currentStep = this.initialStep;
      this.$emit('cancel');
    },
  },
};
</script>

<template>
  <ul class="workflow-container gl-relative gl-ml-3 gl-list-none gl-ps-0">
    <li
      v-for="(step, index) in steps"
      :key="index"
      class="workflow-step"
      :class="{
        active: index === currentStep,
        completed: index < currentStep,
        disabled: index > currentStep,
      }"
    >
      <div
        data-testid="step-header"
        :class="{
          'gl-heading-4': true,
          'gl-font-normal gl-text-subtle': index !== currentStep,
        }"
      >
        {{ step.label }}
      </div>

      <div v-if="index === currentStep" data-testid="stepper-content">
        <div :key="currentStep" data-testid="step-content">
          <slot :name="`step-${currentStep}`" :step="steps[currentStep]">
            <div data-testid="default-content">
              <h2>{{ steps[currentStep].label }}</h2>
              <p>{{ steps[currentStep].description }}</p>
            </div>
          </slot>
        </div>
      </div>

      <slot v-if="index < currentStep" :name="`complete-step-${index}`"></slot>

      <div v-if="index === currentStep" class="gl-mt-5 gl-flex gl-gap-3">
        <gl-button
          v-if="showBackButton && currentStep > 0"
          data-testid="stepper-back"
          @click="previousStep"
        >
          {{ __('Back') }}
        </gl-button>

        <gl-button
          v-if="showNextButton && currentStep < steps.length - 1"
          data-testid="stepper-next"
          variant="confirm"
          :disabled="currentStep === steps.length - 1"
          @click="nextStep"
        >
          {{ __('Next') }}
        </gl-button>

        <gl-button
          v-if="showFinishButton && currentStep === steps.length - 1"
          :loading="isUpdating"
          variant="confirm"
          data-testid="stepper-finish"
          @click="finish"
        >
          {{ __('Save') }}
        </gl-button>

        <gl-button v-if="showCancelButton" data-testid="stepper-cancel" @click="cancel">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </li>
  </ul>
</template>
