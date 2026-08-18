<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    defaultText: s__('SecurityOrchestration|Fetching the scope information.'),
  },
  name: 'LoaderWithMessage',
  components: {
    GlLoadingIcon,
  },
  props: {
    message: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    loadingMessage() {
      return this.message || this.$options.i18n.defaultText;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-baseline gl-gap-3">
    <gl-loading-icon inline />
    <span data-testid="loading-text">{{ loadingMessage }}</span>
  </div>
</template>
