<script>
import PushesChart from 'ee/analytics/contribution_analytics/components/pushes_chart.vue';

export default {
  name: 'ContributionsPushesChart',
  components: {
    PushesChart,
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
  <pushes-chart :pushes="data" />
</template>
