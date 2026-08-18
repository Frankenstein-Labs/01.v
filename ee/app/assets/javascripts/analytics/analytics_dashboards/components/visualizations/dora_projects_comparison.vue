<script>
import ComparisonTable from 'ee/analytics/dashboards/dora_projects_comparison/components/comparison_table.vue';

export default {
  name: 'DoraProjectsComparison',
  components: {
    ComparisonTable,
  },
  props: {
    data: {
      type: Array,
      required: true,
    },
  },
};
</script>

<template>
  <comparison-table :projects="data" />
</template>
