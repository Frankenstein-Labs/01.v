<script>
import { buildClient } from '~/observability/client';
import MetricsList from './list/metrics_list.vue';

export default {
  name: 'MetricsListIndex',
  components: {
    MetricsList,
  },
  props: {
    apiConfig: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      observabilityClient: buildClient(this.apiConfig),
    };
  },
};
</script>

<template>
  <metrics-list :observability-client="observabilityClient" />
</template>
