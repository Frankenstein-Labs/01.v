<script>
import IssuesChart from 'ee/analytics/contribution_analytics/components/issues_chart.vue';

export default {
  name: 'ContributionsIssuesChart',
  components: {
    IssuesChart,
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
  <issues-chart :issues="data" />
</template>
