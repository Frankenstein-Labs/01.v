<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DisabledSection',
  components: {
    GlAlert,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
  },
  i18n: {
    SYNTAX_ERROR: s__('SecurityOrchestration|Invalid syntax'),
  },
};
</script>

<template>
  <div class="gl-mt-7">
    <slot name="title"></slot>
    <gl-alert
      v-if="disabled"
      :title="$options.i18n.SYNTAX_ERROR"
      variant="warning"
      :dismissible="false"
      class="gl-mt-4"
    >
      {{ error }}
    </gl-alert>
    <div class="gl-relative">
      <slot></slot>

      <div
        v-if="disabled"
        class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-0 gl-z-2 gl-bg-default gl-opacity-5"
        data-testid="disabled-section-overlay"
      ></div>
    </div>
  </div>
</template>
