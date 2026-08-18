<script>
import { GlAnimatedChevronLgRightDownIcon, GlCollapse } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  components: {
    GlCollapse,
    GlAnimatedChevronLgRightDownIcon,
  },
  mixins: [glSlotsMixin],
  props: {
    items: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      selectedItems: [],
    };
  },
  methods: {
    toggleDetails(item) {
      if (this.selectedItems.includes(item)) {
        this.selectedItems = this.selectedItems.filter((i) => i !== item);
      } else {
        this.selectedItems.push(item);
      }
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div v-for="(item, index) in items" :key="index">
      <div
        role="button"
        class="gl-flex gl-cursor-pointer gl-select-none gl-flex-row gl-items-center gl-bg-strong gl-px-5 gl-py-3"
        @click="toggleDetails(item)"
      >
        <div>
          <slot name="header" :item="item"></slot>
        </div>
        <gl-animated-chevron-lg-right-down-icon
          class="gl-ml-auto"
          :is-on="selectedItems.includes(item)"
        />
      </div>
      <gl-collapse :visible="selectedItems.includes(item)" class="gl-p-3 gl-pl-5">
        <template v-if="glSlots().default" #default><slot :item="item"></slot></template>
      </gl-collapse>
    </div>
  </div>
</template>
