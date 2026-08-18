<script>
import { defineAsyncComponent } from 'vue';
import { isOfTypeList } from './utils';

export default {
  name: 'ReportTypeList',
  isOfTypeList,
  components: {
    ReportItem: defineAsyncComponent(() => import('../report_item.vue')),
  },
  inheritAttrs: false,
  props: {
    items: {
      type: Array,
      required: true,
    },
  },
  computed: {
    hasNestedListItems() {
      return this.items.some(isOfTypeList);
    },
  },
};
</script>
<template>
  <ul class="generic-report-list" :class="{ 'generic-report-list-nested': hasNestedListItems }">
    <li
      v-for="item in items"
      :key="item.name"
      :class="{ '!gl-list-none': $options.isOfTypeList(item) }"
    >
      <report-item :item="item" data-testid="reportItem" />
    </li>
  </ul>
</template>
