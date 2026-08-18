<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'AiCatalogFormButtons',
  components: {
    GlButton,
  },
  props: {
    isDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    cancelRoute: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-gap-3">
    <slot></slot>
    <gl-button
      :disabled="isDisabled"
      :to="cancelRoute"
      type="button"
      category="secondary"
      class="gl-w-full @sm/panel:gl-w-auto"
    >
      {{ __('Cancel') }}
    </gl-button>
  </div>
</template>
