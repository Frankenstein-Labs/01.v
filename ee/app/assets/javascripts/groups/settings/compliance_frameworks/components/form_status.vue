<script>
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';

export default {
  name: 'FormStatus',
  components: {
    GlAlert,
    GlLoadingIcon,
  },
  props: {
    error: {
      type: String,
      required: false,
      default: null,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <div class="gl-border-t-1 gl-border-t-default gl-pt-5 gl-border-t-solid">
    <gl-alert v-if="error" class="gl-mb-5" variant="danger" :dismissible="false">
      {{ error }}
    </gl-alert>
    <gl-loading-icon v-if="loading" size="lg" />

    <slot v-else></slot>
  </div>
</template>
