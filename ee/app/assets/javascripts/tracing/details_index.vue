<script>
import { buildClient } from '~/observability/client';
import TracingDetails from './details/tracing_details.vue';

export default {
  name: 'TracingDetailsIndex',
  components: {
    TracingDetails,
  },
  props: {
    traceId: {
      type: String,
      required: true,
    },
    logsIndexUrl: {
      required: true,
      type: String,
    },
    metricsIndexUrl: {
      required: true,
      type: String,
    },
    apiConfig: {
      type: Object,
      required: true,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    projectFullPath: {
      type: String,
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
  <tracing-details
    :trace-id="traceId"
    :logs-index-url="logsIndexUrl"
    :metrics-index-url="metricsIndexUrl"
    :project-full-path="projectFullPath"
    :observability-client="observabilityClient"
    :create-issue-url="createIssueUrl"
  />
</template>
