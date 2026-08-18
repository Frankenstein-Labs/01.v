<script>
import { defineAsyncComponent } from 'vue';
import { generateKey } from '../utils/epic_utils';

export default {
  name: 'EpicItemContainer',
  components: {
    EpicItem: defineAsyncComponent(() => import('./epic_item.vue')),
  },
  props: {
    clientWidth: {
      type: Number,
      required: false,
      default: 0,
    },
    epicsHaveChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    children: {
      type: Array,
      required: true,
    },
    childLevel: {
      type: Number,
      required: true,
    },
  },
  methods: {
    generateKey,
  },
};
</script>

<template>
  <div class="epic-list-item-container">
    <epic-item
      v-for="child in children"
      :key="generateKey(child)"
      :epic="child"
      :epics-have-children="epicsHaveChildren"
      :client-width="clientWidth"
      :child-level="childLevel"
    />
  </div>
</template>
