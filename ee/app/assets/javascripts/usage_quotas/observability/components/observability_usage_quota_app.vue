<script>
import { buildClient } from '~/observability/client';
import ObservabilityUsageQuota from './observability_usage_quota.vue';

export default {
  name: 'ObservabilityUsageQuotaApp',
  components: {
    ObservabilityUsageQuota,
  },
  inject: {
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
  <section>
    <observability-usage-quota :observability-client="observabilityClient" />
  </section>
</template>
