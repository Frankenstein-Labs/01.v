<script>
import { GlLoadingIcon } from '@gitlab/ui';

export default {
  name: 'PolicyExceptionsLoader',
  components: {
    GlLoadingIcon,
  },
  props: {
    label: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-loading-icon />
    <span v-if="label" data-testid="label">{{ label }}</span>
  </div>
</template>
