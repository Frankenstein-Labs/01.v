<script>
import { buildClient } from '~/observability/client';
import TracingList from './list/tracing_list.vue';

export default {
  name: 'TracingListIndex',
  components: {
    TracingList,
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
  <tracing-list :observability-client="observabilityClient" />
</template>
