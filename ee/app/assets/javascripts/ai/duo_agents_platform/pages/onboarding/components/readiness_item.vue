<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'ReadinessItem',
  components: { GlIcon },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    targetFile: {
      type: String,
      required: false,
      default: '',
    },
    label: {
      type: String,
      required: false,
      default: '',
    },
    iconName: {
      type: String,
      required: false,
      default: '',
    },
    iconVariant: {
      type: String,
      required: false,
      default: 'default',
    },
  },
};
</script>

<template>
  <li
    class="gl-border-b gl-flex gl-items-start gl-justify-between gl-gap-3 gl-border-b-section gl-py-4 last:gl-border-b-0"
  >
    <div class="gl-flex gl-items-start gl-gap-3">
      <gl-icon
        v-if="iconName"
        :name="iconName"
        :variant="iconVariant"
        class="gl-mt-1 gl-shrink-0"
      />
      <div>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <span class="gl-font-bold gl-text-default">{{ title }}</span>
          <span v-if="label" class="gl-text-sm gl-text-subtle" data-testid="readiness-item-label">{{
            label
          }}</span>
          <slot name="label"></slot>
        </div>
        <p v-if="description" class="gl-mb-0 gl-mt-1 gl-text-sm gl-text-subtle">
          {{ description }}
        </p>
        <code v-if="targetFile" class="gl-mt-1 gl-text-sm">{{ targetFile }}</code>
      </div>
    </div>

    <div class="gl-flex gl-shrink-0 gl-items-center gl-gap-3 gl-whitespace-nowrap">
      <slot name="status"></slot>
      <slot name="actions"></slot>
    </div>
  </li>
</template>
