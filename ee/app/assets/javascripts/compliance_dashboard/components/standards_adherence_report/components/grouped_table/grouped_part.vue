<script>
import { GlAnimatedChevronRightDownIcon, GlCollapse } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  components: {
    GlCollapse,
    GlAnimatedChevronRightDownIcon,
  },
  mixins: [glSlotsMixin],
  data() {
    return {
      isOpen: true,
    };
  },
  methods: {
    toggleDetails() {
      this.isOpen = !this.isOpen;
    },
  },
};
</script>
<template>
  <div>
    <div
      class="gl-flex gl-cursor-pointer gl-select-none gl-flex-row gl-items-center gl-px-5 gl-py-3"
      @click="toggleDetails"
    >
      <gl-animated-chevron-right-down-icon class="gl-mr-2" :is-on="isOpen" />
      <div role="button" tabindex="0">
        <slot name="header"></slot>
      </div>
    </div>
    <gl-collapse :visible="isOpen" class="gl-mt-2">
      <template v-if="glSlots().default" #default><slot></slot></template>
    </gl-collapse>
  </div>
</template>
