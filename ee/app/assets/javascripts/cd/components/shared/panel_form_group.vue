<script>
export default {
  name: 'PanelFormGroup',
  props: {
    description: {
      type: String,
      required: false,
      default: '',
    },
    step: {
      type: String,
      required: false,
      default: '',
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <div class="gl-rounded-lg gl-border-1 gl-border-solid gl-border-subtle">
    <div
      class="gl-flex gl-items-center gl-gap-4 gl-border-b-1 gl-border-b-subtle gl-bg-purple-50 gl-px-4 gl-py-4 gl-border-b-solid"
    >
      <div
        class="gl-inline-flex gl-h-6 gl-w-6 gl-shrink-0 gl-items-center gl-justify-center gl-rounded-full gl-bg-purple-500 gl-text-sm gl-font-bold gl-text-white"
        data-testid="step"
      >
        {{ step }}
      </div>
      <div class="gl-grow">
        <div class="gl-font-bold" data-testid="title">{{ title }}</div>
        <div class="gl-text-sm gl-text-subtle" data-testid="description">{{ description }}</div>
      </div>
      <slot name="actions"></slot>
    </div>
    <div class="gl-p-4">
      <slot></slot>
    </div>
  </div>
</template>
