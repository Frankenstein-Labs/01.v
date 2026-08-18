<script>
import MergeRequestsChart from 'ee/analytics/contribution_analytics/components/merge_requests_chart.vue';

export default {
  name: 'ContributionsMergeRequestsChart',
  components: {
    MergeRequestsChart,
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
  <merge-requests-chart :merge-requests="data" />
</template>
