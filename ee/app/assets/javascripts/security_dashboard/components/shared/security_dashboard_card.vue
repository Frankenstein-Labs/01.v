<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  components: {
    GlLoadingIcon,
  },
  mixins: [glSlotsMixin],
  props: {
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <section
    class="gl-flex gl-flex-col gl-rounded-base gl-border-1 gl-border-solid gl-border-default"
  >
    <header class="gl-p-5">
      <h4 class="gl-mb-3 gl-mt-0" data-testid="title">
        <slot name="title"></slot>
      </h4>
      <p class="gl-m-0 gl-text-subtle" data-testid="help-text">
        <slot name="help-text"></slot>
      </p>
      <div v-if="glSlots().controls" class="gl-mt-5" data-testid="controls">
        <slot name="controls"></slot>
      </div>
    </header>

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-12" />
    <slot v-else></slot>
  </section>
</template>
