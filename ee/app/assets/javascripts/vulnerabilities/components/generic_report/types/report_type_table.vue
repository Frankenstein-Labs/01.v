<script>
import { defineAsyncComponent } from 'vue';
import { GlTableLite } from '@gitlab/ui';

export default {
  name: 'ReportTypeTable',
  components: {
    GlTableLite,
    ReportItem: defineAsyncComponent(() => import('../report_item.vue')),
  },
  inheritAttrs: false,
  props: {
    header: {
      type: Array,
      required: true,
    },
    rows: {
      type: Array,
      required: true,
    },
  },
};
</script>
<template>
  <gl-table-lite
    :fields="header"
    :items="rows"
    bordered
    class="!gl-m-0"
    thead-class="gl-border-t-0 gl-border-b-solid gl-border-b-1 gl-border-b-default"
    tbody-tr-class="gl-break-all"
  >
    <template #head()="data">
      <report-item :item="data.field" />
    </template>
    <template #cell()="data">
      <report-item :item="data.value" />
    </template>
  </gl-table-lite>
</template>
